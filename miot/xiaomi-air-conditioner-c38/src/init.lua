-- Xiaomi Air Conditioner C38 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local humidityCap = capabilities["concertmirror08464.xiaomiAcC38Humidity"]
local hSwingCap = capabilities["concertmirror08464.xiaomiAcC38HSwing"]
local vSwingCap = capabilities["concertmirror08464.xiaomiAcC38VSwing"]
local vaneCap = capabilities["concertmirror08464.xiaomiAcC38Vane"]
local ecoCap = capabilities["concertmirror08464.xiaomiAcC38Eco"]
local heaterCap = capabilities["concertmirror08464.xiaomiAcC38Heater"]
local sleepCap = capabilities["concertmirror08464.xiaomiAcC38Sleep"]
local dryerCap = capabilities["concertmirror08464.xiaomiAcC38Dryer"]
local softWindCap = capabilities["concertmirror08464.xiaomiAcC38SoftWind"]
local alarmCap = capabilities["concertmirror08464.xiaomiAcC38Alarm"]
local indicatorCap = capabilities["concertmirror08464.xiaomiAcC38Indicator"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "xiaomi-air-conditioner-c38"

-- MIoT model: xiaomi.aircondition.c38
-- specModel: xiaomi-c38
-- URN: urn:miot-spec-v2:device:air-conditioner:0000A004:xiaomi-c38:1
--
-- Air Conditioner service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 mode, uint8, RW enum: 2=cool, 3=dry, 4=fanOnly, 5=heat
--   piid=4 target-temperature, float, RW range 16..31 step 0.5, celsius
--   piid=7 eco, bool, RW
--   piid=9 heater, bool, RW (auxiliary heater)
--   piid=10 dryer, bool, RW (auto dry after shutdown)
--   piid=11 sleep-mode, bool, RW
--   piid=14 target-humidity, uint8, RW range 0..100
--   piid=15 un-straight-blowing, bool, RW (indirect airflow)
-- Fan Control service (siid=3)
--   piid=2 fan-level, uint8, RW enum: 0=auto, 1..7 levels, 8=max
--   piid=3 horizontal-swing, bool, RW
--   piid=4 vertical-swing, bool, RW
--   piid=5 horizontal-angle, int16, RW enum: 0=off, 1=left sweep,
--     2=freeze left, 3=middle sweep, 4=freeze right, 5=right sweep
-- Environment service (siid=4)
--   piid=7 temperature, float, R, celsius
--   piid=9 relative-humidity, uint8, R, percent
-- Alarm service (siid=5)
--   piid=1 alarm, bool, RW
-- Indicator Light service (siid=6)
--   piid=1 on, bool, RW
--   piid=2 brightness, uint8, RW enum: 1=medium, 2=high
--
-- Not exposed: enhance fan-percent duplicates the fan level, enhance timer and
-- sleep-diy carry schedule blobs, room-size and maxfan-select are comfort
-- presets, power-consumption is a cumulative counter, and the machine-state,
-- flag-bit, iot-linkage, countdown, electricity, maintenance, and
-- single-smart-scene services expose vendor diagnostics or automation state.

local AC_SIID = 2
local POWER_PIID = 1
local MODE_PIID = 2
local TARGET_TEMPERATURE_PIID = 4
local ECO_PIID = 7
local HEATER_PIID = 9
local DRYER_PIID = 10
local SLEEP_PIID = 11
local TARGET_HUMIDITY_PIID = 14
local SOFT_WIND_PIID = 15

local FAN_SIID = 3
local FAN_LEVEL_PIID = 2
local H_SWING_PIID = 3
local V_SWING_PIID = 4
local VANE_PIID = 5

local ENVIRONMENT_SIID = 4
local TEMPERATURE_PIID = 7
local HUMIDITY_PIID = 9

local ALARM_SIID = 5
local ALARM_PIID = 1

local INDICATOR_SIID = 6
local INDICATOR_ON_PIID = 1
local INDICATOR_BRIGHTNESS_PIID = 2

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [2] = "cool",
    [3] = "dry",
    [4] = "fanOnly",
    [5] = "heat"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    cool = 2,
    dry = 3,
    fanOnly = 4,
    heat = 5
}

local SUPPORTED_AC_MODES = {"cool", "dry", "fanOnly", "heat"}

local FAN_MODE_TO_ST = {
    [0] = "auto",
    [1] = "levelOne",
    [2] = "levelTwo",
    [3] = "levelThree",
    [4] = "levelFour",
    [5] = "levelFive",
    [6] = "levelSix",
    [7] = "levelSeven",
    [8] = "max"
}

local ST_TO_FAN_MODE = {
    auto = 0,
    levelOne = 1,
    levelTwo = 2,
    levelThree = 3,
    levelFour = 4,
    levelFive = 5,
    levelSix = 6,
    levelSeven = 7,
    max = 8
}

local SUPPORTED_FAN_MODES = {
    "auto", "levelOne", "levelTwo", "levelThree",
    "levelFour", "levelFive", "levelSix", "levelSeven", "max"
}

local VANE_TO_ST = {
    [0] = "off",
    [1] = "leftSweep",
    [2] = "freezeLeft",
    [3] = "middleSweep",
    [4] = "freezeRight",
    [5] = "rightSweep"
}

local ST_TO_VANE = {
    off = 0,
    leftSweep = 1,
    freezeLeft = 2,
    middleSweep = 3,
    freezeRight = 4,
    rightSweep = 5
}

local INDICATOR_BRIGHTNESS_TO_ST = {
    [1] = "medium",
    [2] = "high"
}

local ST_TO_INDICATOR_BRIGHTNESS = {
    medium = 1,
    high = 2
}

local TARGET_TEMPERATURE_MIN = 16
local TARGET_TEMPERATURE_MAX = 31

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function bool_to_st(value)
    return value and "on" or "off"
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = AC_SIID, piid = POWER_PIID},
        {siid = AC_SIID, piid = MODE_PIID},
        {siid = AC_SIID, piid = TARGET_TEMPERATURE_PIID},
        {siid = AC_SIID, piid = ECO_PIID},
        {siid = AC_SIID, piid = HEATER_PIID},
        {siid = AC_SIID, piid = DRYER_PIID},
        {siid = AC_SIID, piid = SLEEP_PIID},
        {siid = AC_SIID, piid = TARGET_HUMIDITY_PIID},
        {siid = AC_SIID, piid = SOFT_WIND_PIID},
        {siid = FAN_SIID, piid = FAN_LEVEL_PIID},
        {siid = FAN_SIID, piid = H_SWING_PIID},
        {siid = FAN_SIID, piid = V_SWING_PIID},
        {siid = FAN_SIID, piid = VANE_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_ON_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_BRIGHTNESS_PIID}
    }

    local ok, response = pcall(miot.gets, device, ip, token, properties)
    if not ok or not response or not response.result then
        return
    end

    -- The device keeps indicator power and brightness separate, so the exposed
    -- brightness value reports off whenever the light itself is off.
    local indicator_on = nil
    local indicator_brightness = nil

    for _, result in ipairs(response.result) do
        if result.code == 0 then
            local siid = result.siid
            local piid = result.piid
            local value = result.value

            if siid == AC_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(bool_to_st(value)))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(capabilities.airConditionerMode.airConditionerMode(mode))
                    end
                elseif piid == TARGET_TEMPERATURE_PIID then
                    device:emit_event(capabilities.thermostatCoolingSetpoint.coolingSetpoint({
                        value = value,
                        unit = "C"
                    }))
                elseif piid == ECO_PIID then
                    device:emit_event(ecoCap.eco({value = bool_to_st(value)}))
                elseif piid == HEATER_PIID then
                    device:emit_event(heaterCap.auxHeater({value = bool_to_st(value)}))
                elseif piid == DRYER_PIID then
                    device:emit_event(dryerCap.dryer({value = bool_to_st(value)}))
                elseif piid == SLEEP_PIID then
                    device:emit_event(sleepCap.sleepMode({value = bool_to_st(value)}))
                elseif piid == TARGET_HUMIDITY_PIID then
                    device:emit_event(humidityCap.targetHumidity({value = value, unit = "%"}))
                elseif piid == SOFT_WIND_PIID then
                    device:emit_event(softWindCap.softWind({value = bool_to_st(value)}))
                end
            elseif siid == FAN_SIID then
                if piid == FAN_LEVEL_PIID then
                    local fan_mode = FAN_MODE_TO_ST[value]
                    if fan_mode then
                        device:emit_event(capabilities.airConditionerFanMode.fanMode(fan_mode))
                    end
                elseif piid == H_SWING_PIID then
                    device:emit_event(hSwingCap.horizontalSwing({value = bool_to_st(value)}))
                elseif piid == V_SWING_PIID then
                    device:emit_event(vSwingCap.verticalSwing({value = bool_to_st(value)}))
                elseif piid == VANE_PIID then
                    local vane = VANE_TO_ST[value]
                    if vane then
                        device:emit_event(vaneCap.vanePosition({value = vane}))
                    end
                end
            elseif siid == ENVIRONMENT_SIID then
                if piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == HUMIDITY_PIID then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity({value = value, unit = "%"}))
                end
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(alarmCap.alarm({value = bool_to_st(value)}))
            elseif siid == INDICATOR_SIID then
                if piid == INDICATOR_ON_PIID then
                    indicator_on = value
                elseif piid == INDICATOR_BRIGHTNESS_PIID then
                    indicator_brightness = value
                end
            end
        end
    end

    if indicator_on ~= nil then
        if indicator_on == false then
            device:emit_event(indicatorCap.indicatorBrightness({value = "off"}))
        elseif indicator_brightness ~= nil then
            local brightness = INDICATOR_BRIGHTNESS_TO_ST[indicator_brightness]
            if brightness then
                device:emit_event(indicatorCap.indicatorBrightness({value = brightness}))
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

    local ok = pcall(miot.set, device, ip, token, AC_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, AC_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_ac_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    pcall(miot.set, device, ip, token, AC_SIID, POWER_PIID, true)
    local ok = pcall(miot.set, device, ip, token, AC_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(capabilities.airConditionerMode.airConditionerMode(mode))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_cooling_setpoint_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local setpoint = tonumber(command.args.setpoint)
    if not setpoint then return end
    if setpoint < TARGET_TEMPERATURE_MIN or setpoint > TARGET_TEMPERATURE_MAX then return end

    -- The device accepts 0.5 degree steps, so snap the requested value.
    local value = math.floor(setpoint * 2 + 0.5) / 2
    local ok = pcall(miot.set, device, ip, token, AC_SIID, TARGET_TEMPERATURE_PIID, value)
    if ok then
        device:emit_event(capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = value, unit = "C"}))
    end
end

local function set_fan_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local fan_mode = command.args.fanMode
    local value = ST_TO_FAN_MODE[fan_mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, FAN_LEVEL_PIID, value)
    if ok then
        device:emit_event(capabilities.airConditionerFanMode.fanMode(fan_mode))
    end
end

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local humidity = tonumber(command.args.targetHumidity)
    if not humidity then return end

    local value = math.floor(humidity + 0.5)
    if value < 0 or value > 100 then return end

    local ok = pcall(miot.set, device, ip, token, AC_SIID, TARGET_HUMIDITY_PIID, value)
    if ok then
        device:emit_event(humidityCap.targetHumidity({value = value, unit = "%"}))
    end
end

local function set_vane_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local vane = command.args.vanePosition
    local value = ST_TO_VANE[vane]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, VANE_PIID, value)
    if ok then
        device:emit_event(vaneCap.vanePosition({value = vane}))
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

local set_h_swing_handler = make_bool_handler(FAN_SIID, H_SWING_PIID, hSwingCap, "horizontalSwing", "horizontalSwing")
local set_v_swing_handler = make_bool_handler(FAN_SIID, V_SWING_PIID, vSwingCap, "verticalSwing", "verticalSwing")
local set_eco_handler = make_bool_handler(AC_SIID, ECO_PIID, ecoCap, "eco", "eco")
local set_heater_handler = make_bool_handler(AC_SIID, HEATER_PIID, heaterCap, "auxHeater", "auxHeater")
local set_sleep_handler = make_bool_handler(AC_SIID, SLEEP_PIID, sleepCap, "sleepMode", "sleepMode")
local set_dryer_handler = make_bool_handler(AC_SIID, DRYER_PIID, dryerCap, "dryer", "dryer")
local set_soft_wind_handler = make_bool_handler(AC_SIID, SOFT_WIND_PIID, softWindCap, "softWind", "softWind")
local set_alarm_handler = make_bool_handler(ALARM_SIID, ALARM_PIID, alarmCap, "alarm", "alarm")

local function set_indicator_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local brightness = command.args.indicatorBrightness

    if brightness == "off" then
        local ok = pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_ON_PIID, false)
        if ok then
            device:emit_event(indicatorCap.indicatorBrightness({value = "off"}))
        end
        return
    end

    local value = ST_TO_INDICATOR_BRIGHTNESS[brightness]
    if value == nil then return end

    pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_ON_PIID, true)
    local ok = pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_BRIGHTNESS_PIID, value)
    if ok then
        device:emit_event(indicatorCap.indicatorBrightness({value = brightness}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(vaneCap.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.airConditionerMode.supportedAcModes(SUPPORTED_AC_MODES))
    device:emit_event(capabilities.airConditionerMode.airConditionerMode("cool"))
    device:emit_event(capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = 26, unit = "C"}))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity({value = 0, unit = "%"}))
    device:emit_event(capabilities.airConditionerFanMode.supportedAcFanModes(SUPPORTED_FAN_MODES))
    device:emit_event(capabilities.airConditionerFanMode.fanMode("auto"))
    device:emit_event(humidityCap.targetHumidity({value = 50, unit = "%"}))
    device:emit_event(hSwingCap.horizontalSwing({value = "off"}))
    device:emit_event(vSwingCap.verticalSwing({value = "off"}))
    device:emit_event(vaneCap.vanePosition({value = "off"}))
    device:emit_event(ecoCap.eco({value = "off"}))
    device:emit_event(heaterCap.auxHeater({value = "off"}))
    device:emit_event(sleepCap.sleepMode({value = "off"}))
    device:emit_event(dryerCap.dryer({value = "off"}))
    device:emit_event(softWindCap.softWind({value = "off"}))
    device:emit_event(alarmCap.alarm({value = "off"}))
    device:emit_event(indicatorCap.indicatorBrightness({value = "high"}))
end

local function device_init(_, device)
    ensure_profile(device)
    device:online()

    -- Re-publish the supported lists so the app keeps the selectable options.
    device:emit_event(capabilities.airConditionerMode.supportedAcModes(SUPPORTED_AC_MODES))
    device:emit_event(capabilities.airConditionerFanMode.supportedAcFanModes(SUPPORTED_FAN_MODES))

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

local driver = Driver("miot-xiaomi-air-conditioner-c38", {
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
        [capabilities.airConditionerMode.ID] = {
            [capabilities.airConditionerMode.commands.setAirConditionerMode.NAME] = set_ac_mode_handler
        },
        [capabilities.thermostatCoolingSetpoint.ID] = {
            [capabilities.thermostatCoolingSetpoint.commands.setCoolingSetpoint.NAME] = set_cooling_setpoint_handler
        },
        [capabilities.airConditionerFanMode.ID] = {
            [capabilities.airConditionerFanMode.commands.setFanMode.NAME] = set_fan_mode_handler
        },
        [humidityCap.ID] = {
            [humidityCap.commands.setTargetHumidity.NAME] = set_target_humidity_handler
        },
        [hSwingCap.ID] = {
            [hSwingCap.commands.setHorizontalSwing.NAME] = set_h_swing_handler
        },
        [vSwingCap.ID] = {
            [vSwingCap.commands.setVerticalSwing.NAME] = set_v_swing_handler
        },
        [vaneCap.ID] = {
            [vaneCap.commands.setVanePosition.NAME] = set_vane_handler
        },
        [ecoCap.ID] = {
            [ecoCap.commands.setEco.NAME] = set_eco_handler
        },
        [heaterCap.ID] = {
            [heaterCap.commands.setAuxHeater.NAME] = set_heater_handler
        },
        [sleepCap.ID] = {
            [sleepCap.commands.setSleepMode.NAME] = set_sleep_handler
        },
        [dryerCap.ID] = {
            [dryerCap.commands.setDryer.NAME] = set_dryer_handler
        },
        [softWindCap.ID] = {
            [softWindCap.commands.setSoftWind.NAME] = set_soft_wind_handler
        },
        [alarmCap.ID] = {
            [alarmCap.commands.setAlarm.NAME] = set_alarm_handler
        },
        [indicatorCap.ID] = {
            [indicatorCap.commands.setIndicatorBrightness.NAME] = set_indicator_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
