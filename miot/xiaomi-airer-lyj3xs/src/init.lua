-- Xiaomi Airer LYJ3XS Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local motorControl = capabilities["concertmirror08464.xiaomiAirerLyj3Motor"]
local motorStatus = capabilities["concertmirror08464.xiaomiAirerLyj3Status"]
local faultStatus = capabilities["concertmirror08464.xiaomiAirerLyj3Fault"]
local nightLightControl = capabilities["concertmirror08464.xiaomiAirerLyj3NightLight"]
local nightLevelControl = capabilities["concertmirror08464.xiaomiAirerLyj3NightLevel"]
local alarmControl = capabilities["concertmirror08464.xiaomiAirerLyj3Alarm"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "xiaomi-airer-lyj3xs"

-- MIoT model: xiaomi.airer.lyj3xs
-- specModel: xiaomi-lyj3xs
-- URN: urn:miot-spec-v2:device:airer:0000A00D:xiaomi-lyj3xs:1:0000D067
--
-- Airer service (siid=2)
--   piid=1 fault, uint32, R enum: 0=none, 1=obstacle, 2=overweight, 4=motor
--   piid=2 status, uint8, R enum: 0=stop, 1=rising, 2=down,
--     3=stopUpperLimit, 4=stopLowerLimit
--   piid=5 motor-control, uint8, W enum: 0=pause, 1=up, 2=down
--     Values 3..5 repeat pause and the limit-setting variants, so the exposed
--     control keeps only the three everyday commands.
--   piid=11 current-position, uint8, R, 0..100 %
--   piid=12 target-position, uint8, RW, 0..100 %
--   piid=13/14 motion start and end positions are travel calibration and
--     piid=16 convergent plus piid=17 run-speed are motion tuning, so none of
--     them are exposed
-- Light service (siid=3)
--   piid=1 on, bool, RW
--   piid=2 brightness, uint8, RW, 1..100 %
--   piid=4 color-temperature, uint32, RW, 3000..6500 K, step 100
--   piid=5 night-light-switch, bool, RW
--   piid=6 night-brightness, uint8, RW, 1..100 %
--   aiid=1 toggle and aiid=2 set-night-light duplicate the writes above
-- Alarm service (siid=5)
--   piid=1 alarm, bool, RW
--
-- The rack position uses the standard windowShade capabilities so the app can
-- raise, lower, and pause it, while the light uses switch, switchLevel, and
-- colorTemperature.

local AIRER_SIID = 2
local FAULT_PIID = 1
local STATUS_PIID = 2
local MOTOR_CONTROL_PIID = 5
local CURRENT_POSITION_PIID = 11
local TARGET_POSITION_PIID = 12

local LIGHT_SIID = 3
local LIGHT_ON_PIID = 1
local LIGHT_BRIGHTNESS_PIID = 2
local COLOR_TEMPERATURE_PIID = 4
local NIGHT_LIGHT_PIID = 5
local NIGHT_BRIGHTNESS_PIID = 6

local ALARM_SIID = 5
local ALARM_PIID = 1

-- MIoT -> SmartThings
local FAULT_TO_ST = {
    [0] = "none",
    [1] = "obstacle",
    [2] = "overweight",
    [4] = "motor"
}

local STATUS_TO_ST = {
    [0] = "stop",
    [1] = "rising",
    [2] = "down",
    [3] = "upperLimit",
    [4] = "lowerLimit"
}

-- SmartThings -> MIoT
local ST_TO_MOTOR = {
    pause = 0,
    up = 1,
    down = 2
}

local SHADE_STATE_TO_ST = {
    [0] = "partially open",
    [1] = "opening",
    [2] = "closing",
    [3] = "open",
    [4] = "closed"
}

local COLOR_TEMPERATURE_MIN = 3000
local COLOR_TEMPERATURE_MAX = 6500

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(motorControl.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = AIRER_SIID, piid = FAULT_PIID},
        {siid = AIRER_SIID, piid = STATUS_PIID},
        {siid = AIRER_SIID, piid = CURRENT_POSITION_PIID},
        {siid = LIGHT_SIID, piid = LIGHT_ON_PIID},
        {siid = LIGHT_SIID, piid = LIGHT_BRIGHTNESS_PIID},
        {siid = LIGHT_SIID, piid = COLOR_TEMPERATURE_PIID},
        {siid = LIGHT_SIID, piid = NIGHT_LIGHT_PIID},
        {siid = LIGHT_SIID, piid = NIGHT_BRIGHTNESS_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID}
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

            if siid == AIRER_SIID then
                if piid == FAULT_PIID then
                    local fault = FAULT_TO_ST[value]
                    if fault then
                        device:emit_event(faultStatus.airerFault({value = fault}))
                    end
                elseif piid == STATUS_PIID then
                    local status = STATUS_TO_ST[value]
                    if status then
                        device:emit_event(motorStatus.airerStatus({value = status}))
                    end
                    local shade = SHADE_STATE_TO_ST[value]
                    if shade then
                        device:emit_event(capabilities.windowShade.windowShade(shade))
                    end
                elseif piid == CURRENT_POSITION_PIID then
                    device:emit_event(capabilities.windowShadeLevel.shadeLevel(value))
                end
            elseif siid == LIGHT_SIID then
                if piid == LIGHT_ON_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == LIGHT_BRIGHTNESS_PIID then
                    device:emit_event(capabilities.switchLevel.level(value))
                elseif piid == COLOR_TEMPERATURE_PIID then
                    device:emit_event(capabilities.colorTemperature.colorTemperature(value))
                elseif piid == NIGHT_LIGHT_PIID then
                    device:emit_event(nightLightControl.nightLight({value = value and "on" or "off"}))
                elseif piid == NIGHT_BRIGHTNESS_PIID then
                    device:emit_event(nightLevelControl.nightBrightness({value = value, unit = "%"}))
                end
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(alarmControl.alarm({value = value and "on" or "off"}))
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

local function refresh_soon(device)
    device.thread:call_with_delay(1, function()
        pcall(poll_device_status, device)
    end)
end

local function write_motor(device, motor)
    local ip, token = get_device_config(device)
    if not ip then return false end

    local value = ST_TO_MOTOR[motor]
    if value == nil then return false end

    local ok = pcall(miot.set, device, ip, token, AIRER_SIID, MOTOR_CONTROL_PIID, value)
    if ok then
        device:emit_event(motorControl.motorControl({value = motor}))
        refresh_soon(device)
    end
    return ok
end

local function set_motor_handler(_, device, command)
    write_motor(device, command.args.motorControl)
end

local function shade_open_handler(_, device, _)
    write_motor(device, "up")
end

local function shade_close_handler(_, device, _)
    write_motor(device, "down")
end

local function shade_pause_handler(_, device, _)
    write_motor(device, "pause")
end

local function set_shade_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = tonumber(command.args.shadeLevel)
    if not level then return end

    local value = math.floor(clamp(level, 0, 100))
    local ok = pcall(miot.set, device, ip, token, AIRER_SIID, TARGET_POSITION_PIID, value)
    if ok then
        device:emit_event(capabilities.windowShadeLevel.shadeLevel(value))
        refresh_soon(device)
    end
end

local function switch_on_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_ON_PIID, true)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
    end
end

local function switch_off_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_ON_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = tonumber(command.args.level)
    if not level then return end

    -- The device rejects 0, so turning the light off uses the switch instead.
    if level <= 0 then
        local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_ON_PIID, false)
        if ok then
            device:emit_event(capabilities.switch.switch.off())
        end
        return
    end

    local value = math.floor(clamp(level, 1, 100))
    pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_ON_PIID, true)
    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_BRIGHTNESS_PIID, value)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(capabilities.switchLevel.level(value))
    end
end

local function set_color_temperature_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local kelvin = tonumber(command.args.temperature)
    if not kelvin then return end

    -- The device accepts 100 K steps inside 3000..6500.
    local bounded = clamp(kelvin, COLOR_TEMPERATURE_MIN, COLOR_TEMPERATURE_MAX)
    local value = math.floor(bounded / 100 + 0.5) * 100
    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, COLOR_TEMPERATURE_PIID, value)
    if ok then
        device:emit_event(capabilities.colorTemperature.colorTemperature(value))
    end
end

local function set_night_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.nightLight
    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, NIGHT_LIGHT_PIID, requested == "on")
    if ok then
        device:emit_event(nightLightControl.nightLight({value = requested}))
    end
end

local function set_night_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = tonumber(command.args.nightBrightness)
    if not level then return end

    local value = math.floor(clamp(level, 1, 100))
    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, NIGHT_BRIGHTNESS_PIID, value)
    if ok then
        device:emit_event(nightLevelControl.nightBrightness({value = value, unit = "%"}))
    end
end

local function set_alarm_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.alarm
    local ok = pcall(miot.set, device, ip, token, ALARM_SIID, ALARM_PIID, requested == "on")
    if ok then
        device:emit_event(alarmControl.alarm({value = requested}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:online()
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.switchLevel.level(50))
    device:emit_event(capabilities.colorTemperature.colorTemperature(4000))
    device:emit_event(capabilities.windowShade.windowShade("closed"))
    device:emit_event(capabilities.windowShadeLevel.shadeLevel(0))
    device:emit_event(motorControl.motorControl({value = "pause"}))
    device:emit_event(motorStatus.airerStatus({value = "stop"}))
    device:emit_event(faultStatus.airerFault({value = "none"}))
    device:emit_event(nightLightControl.nightLight({value = "off"}))
    device:emit_event(nightLevelControl.nightBrightness({value = 50, unit = "%"}))
    device:emit_event(alarmControl.alarm({value = "off"}))
    pcall(poll_device_status, device)
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

local driver = Driver("miot-xiaomi-airer-lyj3xs", {
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
        [capabilities.switchLevel.ID] = {
            [capabilities.switchLevel.commands.setLevel.NAME] = set_level_handler
        },
        [capabilities.colorTemperature.ID] = {
            [capabilities.colorTemperature.commands.setColorTemperature.NAME] = set_color_temperature_handler
        },
        [capabilities.windowShade.ID] = {
            [capabilities.windowShade.commands.open.NAME] = shade_open_handler,
            [capabilities.windowShade.commands.close.NAME] = shade_close_handler,
            [capabilities.windowShade.commands.pause.NAME] = shade_pause_handler
        },
        [capabilities.windowShadeLevel.ID] = {
            [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = set_shade_level_handler
        },
        [motorControl.ID] = {
            [motorControl.commands.setMotorControl.NAME] = set_motor_handler
        },
        [nightLightControl.ID] = {
            [nightLightControl.commands.setNightLight.NAME] = set_night_light_handler
        },
        [nightLevelControl.ID] = {
            [nightLevelControl.commands.setNightBrightness.NAME] = set_night_level_handler
        },
        [alarmControl.ID] = {
            [alarmControl.commands.setAlarm.NAME] = set_alarm_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
