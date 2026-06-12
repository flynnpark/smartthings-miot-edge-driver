-- Mi Smart Standing Fan 1X Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miio = require "miio"

local fanControls = capabilities["concertmirror08464.dmakerFanP5Controls"]

local fanSpeedPercent = capabilities["fanSpeedPercent"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "dmaker-fan-p5"

-- miIO model: dmaker.fan.p5
-- Product: Mi Smart Standing Fan 1X
--
-- python-miio FanP5 mapping:
--   get_prop properties:
--     "power", R: boolean on/off
--     "mode", R: "normal" / "nature"
--     "speed", R: fan speed, 0..100
--     "roll_enable", R: horizontal oscillation on/off
--     "roll_angle", R: 30/60/90/120/140, not exposed
--     "time_off", R: delayed off, not exposed
--     "light", R: indicator light on/off
--     "beep_sound", R: buzzer on/off
--     "child_lock", R: child lock on/off
--   write methods:
--     "s_power", W: boolean
--     "s_mode", W: "normal" / "nature"
--     "s_speed", W: 0..100
--     "s_roll", W: boolean
--     "s_angle", W: 30/60/90/120/140, not exposed
--     "s_light", W: boolean
--     "s_sound", W: boolean
--     "s_lock", W: boolean

local PROPERTIES = {
    "power",
    "mode",
    "speed",
    "roll_enable",
    "roll_angle",
    "time_off",
    "light",
    "beep_sound",
    "child_lock"
}

local ST_TO_MODE = {
    normal = "normal",
    nature = "nature"
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
    if not device:supports_capability_by_id(fanControls.ID) then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function emit_on_off(device, capability_attr, value)
    device:emit_event(capability_attr({value = value and "on" or "off"}))
end

local ANGLE_PROPERTIES = {
    {property = "roll_angle", attr = fanControls.horizontalAngle}
}

local function emit_angle_values(device, values)
    for _, property in ipairs(ANGLE_PROPERTIES) do
        local value = values[property.property]
        if type(value) == "number" then
            device:emit_event(property.attr({value = math.floor(value)}))
        end
    end
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local response = miio.cmd(device, ip, token, "get_prop", PROPERTIES)
    if not response or not response.result then
        return
    end

    local values = {}
    for index, property in ipairs(PROPERTIES) do
        values[property] = response.result[index]
    end

    if values.power ~= nil then
        device:emit_event(capabilities.switch.switch(values.power and "on" or "off"))
    end

    if values.mode == "normal" or values.mode == "nature" then
        device:emit_event(fanControls.fanMode({value = values.mode}))
    end

    if type(values.speed) == "number" then
        device:emit_event(fanSpeedPercent.percent({value = values.speed, unit = "%"}))
    end

    if values.roll_enable ~= nil then
        device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(values.roll_enable and "horizontal" or "off"))
    end

    if values.light ~= nil then
        emit_on_off(device, fanControls.indicatorLight, values.light)
    end

    if values.beep_sound ~= nil then
        emit_on_off(device, fanControls.buzzer, values.beep_sound)
    end

    if values.child_lock ~= nil then
        emit_on_off(device, fanControls.childLock, values.child_lock)
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
    if ip and miio.set_prop(device, ip, token, "s_power", {true}) then
        device:emit_event(capabilities.switch.switch.on())
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function switch_off_handler(_, device, _)
    local ip, token = get_device_config(device)
    if ip and miio.set_prop(device, ip, token, "s_power", {false}) then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_fan_speed_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local speed = math.max(0, math.min(100, command.args.percent))
    if miio.set_prop(device, ip, token, "s_speed", {speed}) then
        device:emit_event(fanSpeedPercent.percent({value = speed, unit = "%"}))
    end
end

local function set_fan_oscillation_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.fanOscillationMode
    if mode ~= "off" and mode ~= "horizontal" then return end

    if miio.set_prop(device, ip, token, "s_roll", {mode == "horizontal"}) then
        device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(mode))
    end
end

local function set_fan_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = ST_TO_MODE[command.args.mode]
    if not mode then return end

    if miio.set_prop(device, ip, token, "s_mode", {mode}) then
        device:emit_event(fanControls.fanMode({value = mode}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator_light = command.args.indicatorLight
    if miio.set_prop(device, ip, token, "s_light", {indicator_light == "on"}) then
        device:emit_event(fanControls.indicatorLight({value = indicator_light}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local buzzer = command.args.buzzer
    if miio.set_prop(device, ip, token, "s_sound", {buzzer == "on"}) then
        device:emit_event(fanControls.buzzer({value = buzzer}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    if miio.set_prop(device, ip, token, "s_lock", {child_lock == "on"}) then
        device:emit_event(fanControls.childLock({value = child_lock}))
    end
end

local function set_horizontal_angle_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local angle = math.floor(command.args.horizontalAngle)
    if miio.set_prop(device, ip, token, "s_angle", {angle}) then
        device:emit_event(fanControls.horizontalAngle({value = angle}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(fanSpeedPercent.percent({value = 0, unit = "%"}))
    device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes({value = SUPPORTED_OSCILLATION_MODES}))
    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode("off"))
    device:emit_event(fanControls.fanMode({value = "normal"}))
    device:emit_event(fanControls.indicatorLight({value = "on"}))
    device:emit_event(fanControls.buzzer({value = "off"}))
    device:emit_event(fanControls.childLock({value = "off"}))
    device:emit_event(fanControls.horizontalAngle({value = 30}))
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

local driver = Driver("miio-dmaker-fan-p5", {
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
        [fanControls.ID] = {
            [fanControls.commands.setFanMode.NAME] = set_fan_mode_handler,
            [fanControls.commands.setIndicatorLight.NAME] = set_indicator_light_handler,
            [fanControls.commands.setBuzzer.NAME] = set_buzzer_handler,
            [fanControls.commands.setChildLock.NAME] = set_child_lock_handler,
            [fanControls.commands.setHorizontalAngle.NAME] = set_horizontal_angle_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()

