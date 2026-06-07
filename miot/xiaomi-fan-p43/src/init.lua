-- Xiaomi Fan P43 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local fanControls = capabilities["concertmirror08464.xiaomiFanP43Controls"]

local fanSpeedPercent = capabilities["fanSpeedPercent"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60

-- MIoT model: xiaomi.fan.p43
-- Source: exact MIoT spec urn:miot-spec-v2:device:fan:0000A005:xiaomi-p43:2
-- Fan service (siid=2)
local FAN_SIID = 2
local POWER_PIID = 1
local FAN_LEVEL_PIID = 2          -- level bucket, not exposed
local MODE_PIID = 3               -- 0=Normal, 1=Nature, 2=Smart
local SWING_MODE_PIID = 4         -- horizontal oscillation on/off
local SWING_ANGLE_PIID = 5        -- 30, 60, 90; not exposed
local FAN_SPEED_PIID = 6          -- 1..100

-- Auxiliary services
local INDICATOR_LIGHT_SIID = 4
local BUZZER_SIID = 5
local CHILD_LOCK_SIID = 6
local CHILD_LOCK_PIID = 1
local INDICATOR_LIGHT_PIID = 1
local BUZZER_PIID = 1

local MODE_TO_ST = {
    [0] = "normal",
    [1] = "nature",
    [2] = "smart"
}

local ST_TO_MODE = {
    normal = 0,
    nature = 1,
    smart = 2
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

local function emit_on_off(device, capability_attr, value)
    device:emit_event(capability_attr({value = value and "on" or "off"}))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = FAN_SIID, piid = POWER_PIID},
        {siid = FAN_SIID, piid = FAN_LEVEL_PIID},
        {siid = FAN_SIID, piid = MODE_PIID},
        {siid = FAN_SIID, piid = SWING_MODE_PIID},
        {siid = FAN_SIID, piid = SWING_ANGLE_PIID},
        {siid = FAN_SIID, piid = FAN_SPEED_PIID},
        {siid = INDICATOR_LIGHT_SIID, piid = INDICATOR_LIGHT_PIID},
        {siid = BUZZER_SIID, piid = BUZZER_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID}
    }

    local ok, response = pcall(miot.gets, device, ip, token, properties)
    if not ok or not response or not response.result then
        return
    end

    for _, result in ipairs(response.result) do
        if result.code == 0 then
            local siid = result.siid
            local piid = result.piid
            local value = result.value

            if siid == FAN_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(fanControls.fanMode({value = mode}))
                    end
                elseif piid == SWING_MODE_PIID then
                    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(value and "horizontal" or "off"))
                elseif piid == FAN_SPEED_PIID then
                    device:emit_event(fanSpeedPercent.percent({value = value, unit = "%"}))
                end
            elseif siid == INDICATOR_LIGHT_SIID and piid == INDICATOR_LIGHT_PIID then
                emit_on_off(device, fanControls.indicatorLight, value)
            elseif siid == BUZZER_SIID and piid == BUZZER_PIID then
                emit_on_off(device, fanControls.buzzer, value)
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                emit_on_off(device, fanControls.childLock, value)
            end
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
    if not ip then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, POWER_PIID, true)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function switch_off_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_fan_speed_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local speed = math.max(1, math.min(100, command.args.percent))
    local ok = pcall(miot.set, device, ip, token, FAN_SIID, FAN_SPEED_PIID, speed)
    if ok then
        device:emit_event(fanSpeedPercent.percent({value = speed, unit = "%"}))
    end
end

local function set_fan_oscillation_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.fanOscillationMode
    if mode ~= "off" and mode ~= "horizontal" then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, SWING_MODE_PIID, mode == "horizontal")
    if ok then
        device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(mode))
    end
end

local function set_fan_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(fanControls.fanMode({value = mode}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator_light = command.args.indicatorLight
    local ok = pcall(miot.set, device, ip, token, INDICATOR_LIGHT_SIID, INDICATOR_LIGHT_PIID, indicator_light == "on")
    if ok then
        device:emit_event(fanControls.indicatorLight({value = indicator_light}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local buzzer = command.args.buzzer
    local ok = pcall(miot.set, device, ip, token, BUZZER_SIID, BUZZER_PIID, buzzer == "on")
    if ok then
        device:emit_event(fanControls.buzzer({value = buzzer}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    local ok = pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, child_lock == "on")
    if ok then
        device:emit_event(fanControls.childLock({value = child_lock}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(fanSpeedPercent.percent({value = 1, unit = "%"}))
    device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes({value = SUPPORTED_OSCILLATION_MODES}))
    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode("off"))
    device:emit_event(fanControls.fanMode({value = "normal"}))
    device:emit_event(fanControls.indicatorLight({value = "on"}))
    device:emit_event(fanControls.buzzer({value = "off"}))
    device:emit_event(fanControls.childLock({value = "off"}))
end

local function device_init(_, device)
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

local driver = Driver("miot-xiaomi-fan-p43", {
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
            [fanControls.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
