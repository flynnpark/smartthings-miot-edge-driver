-- Mijia Fan P23 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local fanLevelCap = capabilities["concertmirror08464.dmakerFanP23FanLevel"]
local fanModeCap = capabilities["concertmirror08464.dmakerFanP23FanMode"]
local symmetricCap = capabilities["concertmirror08464.dmakerFanP23Symmetric"]
local leftAngleCap = capabilities["concertmirror08464.dmakerFanP23LeftAngleV2"]
local rightAngleCap = capabilities["concertmirror08464.dmakerFanP23RightAngleV2"]
local heaterOnCap = capabilities["concertmirror08464.dmakerFanP23HeaterOn"]
local targetTempCap = capabilities["concertmirror08464.dmakerFanP23TargetTemp"]
local heatingCap = capabilities["concertmirror08464.dmakerFanP23Heating"]
local offDelayCap = capabilities["concertmirror08464.dmakerFanP23OffDelay"]
local indicatorCap = capabilities["concertmirror08464.dmakerFanP23Indicator"]
local buzzerCap = capabilities["concertmirror08464.dmakerFanP23Buzzer"]
local childLockCap = capabilities["concertmirror08464.dmakerFanP23ChildLock"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "dmaker-fan-p23"

-- MIoT model: dmaker.fan.p23
-- specModel: dmaker-p23
-- URN: urn:miot-spec-v2:device:fan:0000A005:dmaker-p23:1
--
-- This model is a fan and heater combo. The SmartThings switch controls the
-- fan service, and the heater keeps its own power switch, target temperature,
-- and heating flag so the two halves stay independent.
--
-- Heater service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, raw code, not exposed
--   piid=4 mode, uint8, RW, single constant-temperature value, not exposed
--   piid=5 target-temperature, uint8, RW range 18..28, celsius
--   piid=6 heating, bool, RW
-- Physical Controls Locked service (siid=3)
--   piid=1 physical-controls-locked, bool, RW
-- Environment service (siid=4)
--   piid=1 relative-humidity, float, R, percent
--   piid=7 temperature, float, R, celsius
-- Fan service (siid=5)
--   piid=1 on, bool, RW
--   piid=2 fan-level, uint8, RW range 1..10 (stage, separate from the
--     1..100 percent speed in dm-service)
--   piid=3 horizontal-swing, bool, RW
--   piid=4 mode, uint8, RW enum: 0=constant temperature, 1=straight wind,
--     2=natural wind, 3=sleep
-- Alarm service (siid=7)
--   piid=1 alarm, bool, RW
-- Indicator Light service (siid=9)
--   piid=1 on, bool, RW
-- dm-service service (siid=8)
--   piid=1 speed-level, uint8, RW range 1..100 (percent speed)
--   piid=2 symmetrical-swing, bool, RW
--   piid=3 left-angle, uint8, RW range 30..150, step 5
--   piid=4 right-angle, uint8, RW range 0..120, step 5
--   piid=5 off-delay-time, uint16, RW range 0..720 minutes
--   piid=6 swing-lr-manual is a write-only nudge command, not exposed
--
-- The angles are continuous stepped ranges, so the capabilities carry them as
-- strings for iOS compatibility and this driver snaps to the 5 degree step.

local HEATER_SIID = 2
local HEATER_ON_PIID = 1
local TARGET_TEMPERATURE_PIID = 5
local HEATING_PIID = 6

local LOCK_SIID = 3
local LOCK_PIID = 1

local ENVIRONMENT_SIID = 4
local HUMIDITY_PIID = 1
local TEMPERATURE_PIID = 7

local FAN_SIID = 5
local POWER_PIID = 1
local FAN_LEVEL_PIID = 2
local SWING_PIID = 3
local MODE_PIID = 4

local ALARM_SIID = 7
local ALARM_PIID = 1

local INDICATOR_SIID = 9
local INDICATOR_PIID = 1

local DM_SIID = 8
local SPEED_PIID = 1
local SYMMETRIC_PIID = 2
local LEFT_ANGLE_PIID = 3
local RIGHT_ANGLE_PIID = 4
local OFF_DELAY_PIID = 5

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [0] = "constantTemp",
    [1] = "straight",
    [2] = "natural",
    [3] = "sleep"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    constantTemp = 0,
    straight = 1,
    natural = 2,
    sleep = 3
}

local SUPPORTED_OSCILLATION_MODES = {"off", "horizontal"}

local FAN_LEVEL_MIN = 1
local FAN_LEVEL_MAX = 10
local SPEED_MIN = 1
local SPEED_MAX = 100
local LEFT_ANGLE_MIN = 30
local LEFT_ANGLE_MAX = 150
local RIGHT_ANGLE_MIN = 0
local RIGHT_ANGLE_MAX = 120
local ANGLE_STEP = 5
local TARGET_TEMPERATURE_MIN = 18
local TARGET_TEMPERATURE_MAX = 28
local OFF_DELAY_MAX = 720

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(leftAngleCap.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function bool_to_st(value)
    return value and "on" or "off"
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function snap_angle(value, minimum, maximum)
    local stepped = minimum + math.floor((value - minimum) / ANGLE_STEP + 0.5) * ANGLE_STEP
    return math.floor(clamp(stepped, minimum, maximum))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = FAN_SIID, piid = POWER_PIID},
        {siid = FAN_SIID, piid = FAN_LEVEL_PIID},
        {siid = FAN_SIID, piid = SWING_PIID},
        {siid = FAN_SIID, piid = MODE_PIID},
        {siid = DM_SIID, piid = SPEED_PIID},
        {siid = DM_SIID, piid = SYMMETRIC_PIID},
        {siid = DM_SIID, piid = LEFT_ANGLE_PIID},
        {siid = DM_SIID, piid = RIGHT_ANGLE_PIID},
        {siid = DM_SIID, piid = OFF_DELAY_PIID},
        {siid = HEATER_SIID, piid = HEATER_ON_PIID},
        {siid = HEATER_SIID, piid = TARGET_TEMPERATURE_PIID},
        {siid = HEATER_SIID, piid = HEATING_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_PIID},
        {siid = LOCK_SIID, piid = LOCK_PIID}
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
                    device:emit_event(capabilities.switch.switch(bool_to_st(value)))
                elseif piid == FAN_LEVEL_PIID then
                    device:emit_event(fanLevelCap.fanLevel({value = value}))
                elseif piid == SWING_PIID then
                    local mode = value and "horizontal" or "off"
                    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(mode))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(fanModeCap.fanMode({value = mode}))
                    end
                end
            elseif siid == DM_SIID then
                if piid == SPEED_PIID then
                    device:emit_event(capabilities.fanSpeedPercent.percent(math.floor(value)))
                elseif piid == SYMMETRIC_PIID then
                    device:emit_event(symmetricCap.symmetricSwing({value = bool_to_st(value)}))
                elseif piid == LEFT_ANGLE_PIID then
                    device:emit_event(leftAngleCap.leftAngle({value = tostring(math.floor(value))}))
                elseif piid == RIGHT_ANGLE_PIID then
                    device:emit_event(rightAngleCap.rightAngle({value = tostring(math.floor(value))}))
                elseif piid == OFF_DELAY_PIID then
                    device:emit_event(offDelayCap.offDelayTime({value = value, unit = "min"}))
                end
            elseif siid == HEATER_SIID then
                if piid == HEATER_ON_PIID then
                    device:emit_event(heaterOnCap.heaterOn({value = bool_to_st(value)}))
                elseif piid == TARGET_TEMPERATURE_PIID then
                    device:emit_event(targetTempCap.targetTemperature({value = value, unit = "C"}))
                elseif piid == HEATING_PIID then
                    device:emit_event(heatingCap.heating({value = bool_to_st(value)}))
                end
            elseif siid == ENVIRONMENT_SIID then
                if piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == HUMIDITY_PIID then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                end
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(buzzerCap.buzzer({value = bool_to_st(value)}))
            elseif siid == INDICATOR_SIID and piid == INDICATOR_PIID then
                device:emit_event(indicatorCap.indicatorLight({value = bool_to_st(value)}))
            elseif siid == LOCK_SIID and piid == LOCK_PIID then
                device:emit_event(childLockCap.childLock({value = bool_to_st(value)}))
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

local function set_percent_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.percent)
    if not requested then return end

    local value = math.floor(clamp(requested, SPEED_MIN, SPEED_MAX))
    local ok = pcall(miot.set, device, ip, token, DM_SIID, SPEED_PIID, value)
    if ok then
        device:emit_event(capabilities.fanSpeedPercent.percent(value))
    end
end

local function set_fan_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.fanLevel)
    if not requested then return end

    local value = math.floor(clamp(requested, FAN_LEVEL_MIN, FAN_LEVEL_MAX))
    local ok = pcall(miot.set, device, ip, token, FAN_SIID, FAN_LEVEL_PIID, value)
    if ok then
        device:emit_event(fanLevelCap.fanLevel({value = value}))
    end
end

local function set_fan_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.fanMode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(fanModeCap.fanMode({value = mode}))
    end
end

local function set_oscillation_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.fanOscillationMode
    local ok = pcall(miot.set, device, ip, token, FAN_SIID, SWING_PIID, requested == "horizontal")
    if ok then
        device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(requested))
    end
end

local function make_angle_handler(piid, capability, attribute, argument, minimum, maximum)
    return function(_, device, command)
        local ip, token = get_device_config(device)
        if not ip then return end

        local requested = tonumber(command.args[argument])
        if not requested then return end

        local value = snap_angle(requested, minimum, maximum)
        local ok = pcall(miot.set, device, ip, token, DM_SIID, piid, value)
        if ok then
            device:emit_event(capability[attribute]({value = tostring(value)}))
        end
    end
end

local set_left_angle_handler = make_angle_handler(LEFT_ANGLE_PIID, leftAngleCap, "leftAngle", "leftAngle", LEFT_ANGLE_MIN, LEFT_ANGLE_MAX)
local set_right_angle_handler = make_angle_handler(RIGHT_ANGLE_PIID, rightAngleCap, "rightAngle", "rightAngle", RIGHT_ANGLE_MIN, RIGHT_ANGLE_MAX)

local function set_target_temp_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.targetTemperature)
    if not requested then return end

    local value = math.floor(clamp(requested, TARGET_TEMPERATURE_MIN, TARGET_TEMPERATURE_MAX))
    local ok = pcall(miot.set, device, ip, token, HEATER_SIID, TARGET_TEMPERATURE_PIID, value)
    if ok then
        device:emit_event(targetTempCap.targetTemperature({value = value, unit = "C"}))
    end
end

local function set_off_delay_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.offDelayTime)
    if not requested then return end

    local value = math.floor(clamp(requested, 0, OFF_DELAY_MAX))
    local ok = pcall(miot.set, device, ip, token, DM_SIID, OFF_DELAY_PIID, value)
    if ok then
        device:emit_event(offDelayCap.offDelayTime({value = value, unit = "min"}))
    end
end

local function make_bool_handler(siid, piid, capability, attribute, argument)
    return function(_, device, command)
        local ip, token = get_device_config(device)
        if not ip then return end

        local requested = command.args[argument]
        local ok = pcall(miot.set, device, ip, token, siid, piid, requested == "on")
        if ok then
            device:emit_event(capability[attribute]({value = requested}))
        end
    end
end

local set_symmetric_handler = make_bool_handler(DM_SIID, SYMMETRIC_PIID, symmetricCap, "symmetricSwing", "symmetricSwing")
local set_heater_on_handler = make_bool_handler(HEATER_SIID, HEATER_ON_PIID, heaterOnCap, "heaterOn", "heaterOn")
local set_heating_handler = make_bool_handler(HEATER_SIID, HEATING_PIID, heatingCap, "heating", "heating")
local set_buzzer_handler = make_bool_handler(ALARM_SIID, ALARM_PIID, buzzerCap, "buzzer", "buzzer")
local set_indicator_handler = make_bool_handler(INDICATOR_SIID, INDICATOR_PIID, indicatorCap, "indicatorLight", "indicatorLight")
local set_child_lock_handler = make_bool_handler(LOCK_SIID, LOCK_PIID, childLockCap, "childLock", "childLock")

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:online()
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.fanSpeedPercent.percent(1))
    device:emit_event(fanLevelCap.fanLevel({value = 1}))
    device:emit_event(fanModeCap.fanMode({value = "straight"}))
    device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes(SUPPORTED_OSCILLATION_MODES))
    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode("off"))
    device:emit_event(symmetricCap.symmetricSwing({value = "off"}))
    device:emit_event(leftAngleCap.leftAngle({value = "60"}))
    device:emit_event(rightAngleCap.rightAngle({value = "60"}))
    device:emit_event(heaterOnCap.heaterOn({value = "off"}))
    device:emit_event(targetTempCap.targetTemperature({value = 24, unit = "C"}))
    device:emit_event(heatingCap.heating({value = "off"}))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(offDelayCap.offDelayTime({value = 0, unit = "min"}))
    device:emit_event(indicatorCap.indicatorLight({value = "on"}))
    device:emit_event(buzzerCap.buzzer({value = "off"}))
    device:emit_event(childLockCap.childLock({value = "off"}))
    pcall(poll_device_status, device)
end

local function device_init(_, device)
    ensure_profile(device)
    device:online()

    -- Re-publish the oscillation list so the app keeps the options.
    device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes(SUPPORTED_OSCILLATION_MODES))

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

local driver = Driver("miot-dmaker-fan-p23", {
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
        [capabilities.fanSpeedPercent.ID] = {
            [capabilities.fanSpeedPercent.commands.setPercent.NAME] = set_percent_handler
        },
        [capabilities.fanOscillationMode.ID] = {
            [capabilities.fanOscillationMode.commands.setFanOscillationMode.NAME] = set_oscillation_handler
        },
        [fanLevelCap.ID] = {
            [fanLevelCap.commands.setFanLevel.NAME] = set_fan_level_handler
        },
        [fanModeCap.ID] = {
            [fanModeCap.commands.setFanMode.NAME] = set_fan_mode_handler
        },
        [symmetricCap.ID] = {
            [symmetricCap.commands.setSymmetricSwing.NAME] = set_symmetric_handler
        },
        [leftAngleCap.ID] = {
            [leftAngleCap.commands.setLeftAngle.NAME] = set_left_angle_handler
        },
        [rightAngleCap.ID] = {
            [rightAngleCap.commands.setRightAngle.NAME] = set_right_angle_handler
        },
        [heaterOnCap.ID] = {
            [heaterOnCap.commands.setHeaterOn.NAME] = set_heater_on_handler
        },
        [targetTempCap.ID] = {
            [targetTempCap.commands.setTargetTemperature.NAME] = set_target_temp_handler
        },
        [heatingCap.ID] = {
            [heatingCap.commands.setHeating.NAME] = set_heating_handler
        },
        [offDelayCap.ID] = {
            [offDelayCap.commands.setOffDelayTime.NAME] = set_off_delay_handler
        },
        [indicatorCap.ID] = {
            [indicatorCap.commands.setIndicatorLight.NAME] = set_indicator_handler
        },
        [buzzerCap.ID] = {
            [buzzerCap.commands.setBuzzer.NAME] = set_buzzer_handler
        },
        [childLockCap.ID] = {
            [childLockCap.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
