-- Xiaomi Airer Pro 3 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local motorControl = capabilities["concertmirror08464.xiaomiAirerPro3Motor"]
local positionControl = capabilities["concertmirror08464.xiaomiAirerPro3Position"]
local motorStatus = capabilities["concertmirror08464.xiaomiAirerPro3Status"]
local faultStatus = capabilities["concertmirror08464.xiaomiAirerPro3Fault"]
local nightLightControl = capabilities["concertmirror08464.xiaomiAirerPro3NightLight"]
local nightLevelControl = capabilities["concertmirror08464.xiaomiAirerPro3NightLevel"]
local alarmControl = capabilities["concertmirror08464.xiaomiAirerPro3Alarm"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "xiaomi-airer-pro3"

-- MIoT model: xiaomi.airer.pro3
-- specModel: xiaomi-pro3
-- URN: urn:miot-spec-v2:device:airer:0000A00D:xiaomi-pro3:2:0000D067
--
-- Airer service (siid=2)
--   piid=1 fault, uint8, R enum: 0=noFaults, 1=obstacle, 2=overweight, 3=motorFault
--   piid=2 status, uint8, R enum: 0=stopUpperLimit, 1=rising, 2=down, 3=stop, 4=stopLowerLimit
--   piid=5 motor-control, uint8, W enum: 0=pause, 1=up, 2=down
--   piid=12 target-position, uint8, RW, 0..100 %
--   piid=13 motion-start-position, piid=14 motion-end-position: calibration, not exposed
--   aiid=1 set-upper-limit, aiid=2 set-lower-limit: calibration actions, not exposed
-- Light service (siid=3)
--   piid=1 on, bool, RW
--   piid=2 brightness, uint8, RW, 1..100 %
--   piid=4 night-light-switch, bool, RW
--   piid=5 night-brightness, uint8, RW, 1..100 %
--   aiid=1 toggle, action, not exposed
-- Alarm service (siid=5)
--   piid=1 alarm, bool, RW
-- set-night-light service (siid=6): schedule times, motor speed, and current
--   position mirror values, not exposed

local AIRER_SIID = 2
local FAULT_PIID = 1
local STATUS_PIID = 2
local MOTOR_CONTROL_PIID = 5
local TARGET_POSITION_PIID = 12

local LIGHT_SIID = 3
local LIGHT_ON_PIID = 1
local LIGHT_BRIGHTNESS_PIID = 2
local NIGHT_LIGHT_PIID = 4
local NIGHT_BRIGHTNESS_PIID = 5

local ALARM_SIID = 5
local ALARM_PIID = 1

-- MIoT -> SmartThings
local FAULT_TO_ST = {
    [0] = "noFaults",
    [1] = "obstacle",
    [2] = "overweight",
    [3] = "motorFault"
}

local STATUS_TO_ST = {
    [0] = "stopUpperLimit",
    [1] = "rising",
    [2] = "down",
    [3] = "stop",
    [4] = "stopLowerLimit"
}

-- SmartThings -> MIoT
local ST_TO_MOTOR = {
    pause = 0,
    up = 1,
    down = 2
}

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function clamp_percent(value, minimum)
    if value < minimum then
        return minimum
    end
    if value > 100 then
        return 100
    end
    return math.floor(value)
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = AIRER_SIID, piid = FAULT_PIID},
        {siid = AIRER_SIID, piid = STATUS_PIID},
        {siid = AIRER_SIID, piid = TARGET_POSITION_PIID},
        {siid = LIGHT_SIID, piid = LIGHT_ON_PIID},
        {siid = LIGHT_SIID, piid = LIGHT_BRIGHTNESS_PIID},
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
                        device:emit_event(faultStatus.deviceFault({value = fault}))
                    end
                elseif piid == STATUS_PIID then
                    local status = STATUS_TO_ST[value]
                    if status then
                        device:emit_event(motorStatus.motorStatus({value = status}))
                    end
                elseif piid == TARGET_POSITION_PIID then
                    device:emit_event(positionControl.targetPosition({value = value, unit = "%"}))
                end
            elseif siid == LIGHT_SIID then
                if piid == LIGHT_ON_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == LIGHT_BRIGHTNESS_PIID then
                    device:emit_event(capabilities.switchLevel.level(value))
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

    local value = clamp_percent(level, 1)
    pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_ON_PIID, true)
    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_BRIGHTNESS_PIID, value)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(capabilities.switchLevel.level(value))
    end
end

local function set_motor_control_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local control = command.args.motorControl
    local value = ST_TO_MOTOR[control]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, AIRER_SIID, MOTOR_CONTROL_PIID, value)
    if ok then
        device:emit_event(motorControl.motorControl({value = control}))
        device.thread:call_with_delay(3, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_target_position_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local position = tonumber(command.args.position)
    if not position then return end

    local value = clamp_percent(position, 0)
    local ok = pcall(miot.set, device, ip, token, AIRER_SIID, TARGET_POSITION_PIID, value)
    if ok then
        device:emit_event(positionControl.targetPosition({value = value, unit = "%"}))
        device.thread:call_with_delay(3, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_night_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local night = command.args.nightLight
    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, NIGHT_LIGHT_PIID, night == "on")
    if ok then
        device:emit_event(nightLightControl.nightLight({value = night}))
    end
end

local function set_night_brightness_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local brightness = tonumber(command.args.brightness)
    if not brightness then return end

    local value = clamp_percent(brightness, 1)
    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, NIGHT_BRIGHTNESS_PIID, value)
    if ok then
        device:emit_event(nightLevelControl.nightBrightness({value = value, unit = "%"}))
    end
end

local function set_alarm_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local alarm = command.args.alarm
    local ok = pcall(miot.set, device, ip, token, ALARM_SIID, ALARM_PIID, alarm == "on")
    if ok then
        device:emit_event(alarmControl.alarm({value = alarm}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(motorControl.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.switchLevel.level(50))
    device:emit_event(motorControl.motorControl({value = "pause"}))
    device:emit_event(positionControl.targetPosition({value = 0, unit = "%"}))
    device:emit_event(motorStatus.motorStatus({value = "stop"}))
    device:emit_event(faultStatus.deviceFault({value = "noFaults"}))
    device:emit_event(nightLightControl.nightLight({value = "off"}))
    device:emit_event(nightLevelControl.nightBrightness({value = 50, unit = "%"}))
    device:emit_event(alarmControl.alarm({value = "off"}))
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

local driver = Driver("miot-xiaomi-airer-pro3", {
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
        [motorControl.ID] = {
            [motorControl.commands.setMotorControl.NAME] = set_motor_control_handler
        },
        [positionControl.ID] = {
            [positionControl.commands.setTargetPosition.NAME] = set_target_position_handler
        },
        [nightLightControl.ID] = {
            [nightLightControl.commands.setNightLight.NAME] = set_night_light_handler
        },
        [nightLevelControl.ID] = {
            [nightLevelControl.commands.setNightBrightness.NAME] = set_night_brightness_handler
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
