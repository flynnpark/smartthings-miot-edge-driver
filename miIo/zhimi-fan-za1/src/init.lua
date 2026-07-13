-- Zhimi Fan ZA1 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miio = require "miio"

local fanModeCap = capabilities["concertmirror08464.zhimiFanZa1FanMode"]
local ledBrightnessCap = capabilities["concertmirror08464.zhimiFanZa1LedBrightness"]
local buzzerCap = capabilities["concertmirror08464.zhimiFanZa1Buzzer"]
local childLockCap = capabilities["concertmirror08464.zhimiFanZa1ChildLock"]
local horizontalAngleCap = capabilities["concertmirror08464.zhimiFanZa1HorizontalAngleV2"]
local fanSpeedPercent = capabilities["fanSpeedPercent"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "zhimi-fan-za1"
local CURRENT_FAN_MODE = "current_fan_mode"
local CURRENT_PERCENT = "current_percent"

-- miIO model: zhimi.fan.za1
-- Source: python-miio miio.integrations.zhimi.fan.fan classic Fan mapping.
-- Read properties: power, angle_enable, speed_level, natural_level, child_lock,
--                  buzzer, led_b
-- Write methods: set_power, set_speed_level, set_natural_level,
--                set_angle_enable, set_led_b, set_buzzer, set_child_lock
-- ZA1 uses one-property get_prop polling and numeric buzzer values: 2=on, 0=off.

local PROPERTIES = {
    "angle",
    "power",
    "angle_enable",
    "speed_level",
    "natural_level",
    "child_lock",
    "buzzer",
    "led_b"
}

local LED_BRIGHTNESS_TO_ST = {
    [0] = "bright",
    [1] = "dim",
    [2] = "off"
}

local ST_TO_LED_BRIGHTNESS = {
    bright = 0,
    dim = 1,
    off = 2
}

local SUPPORTED_OSCILLATION_MODES = {"off", "horizontal"}

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(horizontalAngleCap.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function on_off_to_bool(value)
    return value == "on" or value == true or value == 1 or value == 2
end

local function emit_on_off(device, capability_attr, value)
    device:emit_event(capability_attr({value = on_off_to_bool(value) and "on" or "off"}))
end

local ANGLE_PROPERTIES = {
    {property = "angle", attr = horizontalAngleCap.horizontalAngle}
}

local function emit_angle_values(device, values)
    for _, property in ipairs(ANGLE_PROPERTIES) do
        local value = values[property.property]
        if type(value) == "number" then
            device:emit_event(property.attr({value = tostring(math.floor(value))}))
        end
    end
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local values = {}
    for _, property in ipairs(PROPERTIES) do
        local response = miio.cmd(device, ip, token, "get_prop", {property})
        if response and response.result then
            values[property] = response.result[1]
        end
    end

    emit_angle_values(device, values)

    if values.power ~= nil then
        device:emit_event(capabilities.switch.switch(on_off_to_bool(values.power) and "on" or "off"))
    end

    local mode = "normal"
    local percent = values.speed_level
    if type(values.natural_level) == "number" and values.natural_level > 0 then
        mode = "nature"
        percent = values.natural_level
    end

    device:set_field(CURRENT_FAN_MODE, mode)
    device:emit_event(fanModeCap.fanMode({value = mode}))

    if type(percent) == "number" then
        local safe_percent = clamp(percent, 1, 100)
        device:set_field(CURRENT_PERCENT, safe_percent)
        device:emit_event(fanSpeedPercent.percent({value = safe_percent, unit = "%"}))
    end

    if values.angle_enable ~= nil then
        device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(on_off_to_bool(values.angle_enable) and "horizontal" or "off"))
    end

    if values.child_lock ~= nil then
        emit_on_off(device, childLockCap.childLock, values.child_lock)
    end

    if values.buzzer ~= nil then
        emit_on_off(device, buzzerCap.buzzer, values.buzzer)
    end

    if type(values.led_b) == "number" then
        local brightness = LED_BRIGHTNESS_TO_ST[values.led_b]
        if brightness then
            device:emit_event(ledBrightnessCap.ledBrightness({value = brightness}))
        end
    end
end

local function start_polling_timer(device)
    local interval = device.preferences.pollingInterval or DEFAULT_POLLING_INTERVAL
    local timer = device.thread:call_on_schedule(interval, function()
        pcall(poll_device_status, device)
    end, "Polling")
    device:set_field(POLLING_TIMER, timer)
end

local function stop_polling_timer(device)
    local timer = device:get_field(POLLING_TIMER)
    if timer then
        device.thread:cancel_timer(timer)
        device:set_field(POLLING_TIMER, nil)
    end
end

local function switch_on_handler(_, device, _)
    local ip, token = get_device_config(device)
    if ip and miio.set_prop(device, ip, token, "set_power", {"on"}) then
        device:emit_event(capabilities.switch.switch.on())
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function switch_off_handler(_, device, _)
    local ip, token = get_device_config(device)
    if ip and miio.set_prop(device, ip, token, "set_power", {"off"}) then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_fan_speed_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local percent = clamp(command.args.percent, 1, 100)
    local mode = device:get_field(CURRENT_FAN_MODE) or "normal"
    local method = mode == "nature" and "set_natural_level" or "set_speed_level"

    if miio.set_prop(device, ip, token, method, {percent}) then
        device:set_field(CURRENT_PERCENT, percent)
        device:emit_event(fanSpeedPercent.percent({value = percent, unit = "%"}))
    end
end

local function set_fan_oscillation_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.fanOscillationMode
    if mode ~= "off" and mode ~= "horizontal" then return end

    if miio.set_prop(device, ip, token, "set_angle_enable", {mode == "horizontal" and "on" or "off"}) then
        device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(mode))
    end
end

local function set_fan_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    if mode ~= "normal" and mode ~= "nature" then return end

    local percent = device:get_field(CURRENT_PERCENT) or 1
    if percent < 1 then percent = 1 end

    local ok
    if mode == "nature" then
        ok = miio.set_prop(device, ip, token, "set_natural_level", {percent})
    else
        ok = miio.set_prop(device, ip, token, "set_natural_level", {0})
    end

    if ok then
        device:set_field(CURRENT_FAN_MODE, mode)
        device:emit_event(fanModeCap.fanMode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_led_brightness_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local brightness = command.args.brightness
    local value = ST_TO_LED_BRIGHTNESS[brightness]
    if value == nil then return end

    if miio.set_prop(device, ip, token, "set_led_b", {value}) then
        device:emit_event(ledBrightnessCap.ledBrightness({value = brightness}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local buzzer = command.args.buzzer
    local value = buzzer == "on" and 2 or 0
    if miio.set_prop(device, ip, token, "set_buzzer", {value}) then
        device:emit_event(buzzerCap.buzzer({value = buzzer}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    if miio.set_prop(device, ip, token, "set_child_lock", {child_lock}) then
        device:emit_event(childLockCap.childLock({value = child_lock}))
    end
end

local function set_horizontal_angle_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local angle = tonumber(command.args.horizontalAngle)
    if not angle then return end
    if miio.set_prop(device, ip, token, "set_angle", {angle}) then
        device:emit_event(horizontalAngleCap.horizontalAngle({value = tostring(angle)}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(fanSpeedPercent.percent({value = 1, unit = "%"}))
    device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes({value = SUPPORTED_OSCILLATION_MODES}))
    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode("off"))
    device:emit_event(fanModeCap.fanMode({value = "normal"}))
    device:emit_event(ledBrightnessCap.ledBrightness({value = "bright"}))
    device:emit_event(buzzerCap.buzzer({value = "off"}))
    device:emit_event(childLockCap.childLock({value = "off"}))
    device:set_field(CURRENT_FAN_MODE, "normal")
    device:set_field(CURRENT_PERCENT, 1)
    device:emit_event(horizontalAngleCap.horizontalAngle({value = "0"}))
end

local function device_init(_, device)
    ensure_profile(device)
    device:online()

    local ip = get_device_config(device)
    if ip then
        start_polling_timer(device)
        pcall(poll_device_status, device)
    end
end

local function device_removed(_, device)
    stop_polling_timer(device)
end

local function device_info_changed(driver, device, _, args)
    ensure_profile(device)
    if not args.old_st_store or not args.old_st_store.preferences then
        return
    end

    local old = args.old_st_store.preferences
    local new = device.preferences

    if old.createDev == false and new.createDev == true then
        discovery.create_device(driver)
    end

    if old.ipAddress ~= new.ipAddress or old.token ~= new.token or old.pollingInterval ~= new.pollingInterval then
        stop_polling_timer(device)

        local ip = get_device_config(device)
        if ip then
            start_polling_timer(device)
            pcall(poll_device_status, device)
        end
    end
end

local driver = Driver("miio-zhimi-fan-za1", {
    discovery = discovery.handle_discovery,
    lifecycle_handlers = {
        added = device_added,
        init = device_init,
        removed = device_removed,
        infoChanged = device_info_changed
    },
    capability_handlers = {
        [capabilities.switch.ID] = {
            [capabilities.switch.commands.on.NAME] = switch_on_handler,
            [capabilities.switch.commands.off.NAME] = switch_off_handler
        },
        [fanSpeedPercent.ID] = {
            [fanSpeedPercent.commands.setPercent.NAME] = set_fan_speed_handler
        },
        [capabilities.fanOscillationMode.ID] = {
            [capabilities.fanOscillationMode.commands.setFanOscillationMode.NAME] = set_fan_oscillation_mode_handler
        },
        [fanModeCap.ID] = {
            [fanModeCap.commands.setFanMode.NAME] = set_fan_mode_handler
        },
        [ledBrightnessCap.ID] = {
            [ledBrightnessCap.commands.setLedBrightness.NAME] = set_led_brightness_handler
        },
        [buzzerCap.ID] = {
            [buzzerCap.commands.setBuzzer.NAME] = set_buzzer_handler
        },
        [childLockCap.ID] = {
            [childLockCap.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [horizontalAngleCap.ID] = {
            [horizontalAngleCap.commands.setHorizontalAngle.NAME] = set_horizontal_angle_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
