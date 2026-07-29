-- Deerma Humidifier 990DW Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local fanLevelControl = capabilities["concertmirror08464.deermaHum990dwFanLevel"]
local targetHumidityControl = capabilities["concertmirror08464.deermaHum990dwTargetHumidity"]
local operatingStatus = capabilities["concertmirror08464.deermaHum990dwStatus"]
local indicatorLightControl = capabilities["concertmirror08464.deermaHum990dwIndicatorLight"]
local alarmControl = capabilities["concertmirror08464.deermaHum990dwAlarm"]
local tankFilledStatus = capabilities["concertmirror08464.deermaHum990dwTankFilled"]
local waterShortageStatus = capabilities["concertmirror08464.deermaHum990dwWaterShortage"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "deerma-humidifier-990dw"

-- MIoT model: deerma.humidifier.990dw
-- specModel: deerma-990dw
-- URN: urn:miot-spec-v2:device:humidifier:0000A00E:deerma-990dw:1
--
-- Humidifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R: 0=noFaults, not exposed
--   piid=3 fan-level, uint8, RW enum: 1..5 levels, 6=constantHumidity, 7=sleep
--   piid=4 status, uint8, R enum: 1=idle, 2=busy
--   piid=5 target-humidity, uint8, RW range 40..70 step 1, %
--   aiid=1 toggle, action, not exposed
-- Environment service (siid=3)
--   piid=1 relative-humidity, uint8, R, 0..100 %
--   piid=2 temperature, float, R, celsius
-- Indicator Light service (siid=4)
--   piid=1 on, bool, RW
-- Alarm service (siid=6)
--   piid=1 alarm, bool, RW
-- custom service (siid=5)
--   piid=1 the-tank-filed, bool, R: true=filled, false=notFilled
--   piid=2 water-shortage-fault, bool, R: true=shortage, false=normal
--   piid=3 humi-sensor-fault, bool, R, not exposed
--   piid=4 temp-sensor-fault, bool, R, not exposed

local HUMIDIFIER_SIID = 2
local POWER_PIID = 1
local FAN_LEVEL_PIID = 3
local STATUS_PIID = 4
local TARGET_HUMIDITY_PIID = 5

local ENVIRONMENT_SIID = 3
local HUMIDITY_PIID = 1
local TEMPERATURE_PIID = 2

local INDICATOR_SIID = 4
local INDICATOR_ON_PIID = 1

local CUSTOM_SIID = 5
local TANK_FILLED_PIID = 1
local WATER_SHORTAGE_PIID = 2

local ALARM_SIID = 6
local ALARM_PIID = 1

-- MIoT -> SmartThings
local FAN_LEVEL_TO_ST = {
    [1] = "levelOne",
    [2] = "levelTwo",
    [3] = "levelThree",
    [4] = "levelFour",
    [5] = "levelFive",
    [6] = "constantHumidity",
    [7] = "sleep"
}

-- SmartThings -> MIoT
local ST_TO_FAN_LEVEL = {
    levelOne = 1,
    levelTwo = 2,
    levelThree = 3,
    levelFour = 4,
    levelFive = 5,
    constantHumidity = 6,
    sleep = 7
}

local STATUS_TO_ST = {
    [1] = "idle",
    [2] = "busy"
}

local TARGET_HUMIDITY_MIN = 40
local TARGET_HUMIDITY_MAX = 70

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
        {siid = HUMIDIFIER_SIID, piid = POWER_PIID},
        {siid = HUMIDIFIER_SIID, piid = FAN_LEVEL_PIID},
        {siid = HUMIDIFIER_SIID, piid = STATUS_PIID},
        {siid = HUMIDIFIER_SIID, piid = TARGET_HUMIDITY_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_ON_PIID},
        {siid = CUSTOM_SIID, piid = TANK_FILLED_PIID},
        {siid = CUSTOM_SIID, piid = WATER_SHORTAGE_PIID},
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

            if siid == HUMIDIFIER_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == FAN_LEVEL_PIID then
                    local level = FAN_LEVEL_TO_ST[value]
                    if level then
                        device:emit_event(fanLevelControl.fanLevel({value = level}))
                    end
                elseif piid == STATUS_PIID then
                    local status = STATUS_TO_ST[value]
                    if status then
                        device:emit_event(operatingStatus.operatingStatus({value = status}))
                    end
                elseif piid == TARGET_HUMIDITY_PIID then
                    device:emit_event(targetHumidityControl.targetHumidity({value = value, unit = "%"}))
                end
            elseif siid == ENVIRONMENT_SIID then
                if piid == HUMIDITY_PIID then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                end
            elseif siid == INDICATOR_SIID and piid == INDICATOR_ON_PIID then
                device:emit_event(indicatorLightControl.indicatorLight({value = bool_to_st(value)}))
            elseif siid == CUSTOM_SIID then
                if piid == TANK_FILLED_PIID then
                    device:emit_event(tankFilledStatus.tankFilled({value = value and "filled" or "notFilled"}))
                elseif piid == WATER_SHORTAGE_PIID then
                    device:emit_event(waterShortageStatus.waterShortage({value = value and "shortage" or "normal"}))
                end
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(alarmControl.alarm({value = bool_to_st(value)}))
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

    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_fan_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = command.args.fanLevel
    local value = ST_TO_FAN_LEVEL[level]
    if value == nil then return end

    pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, POWER_PIID, true)
    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, FAN_LEVEL_PIID, value)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(fanLevelControl.fanLevel({value = level}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local target = tonumber(command.args.humidity)
    if not target then return end
    if target < TARGET_HUMIDITY_MIN or target > TARGET_HUMIDITY_MAX then return end

    local value = math.floor(target)
    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, TARGET_HUMIDITY_PIID, value)
    if ok then
        device:emit_event(targetHumidityControl.targetHumidity({value = value, unit = "%"}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator = command.args.indicatorLight
    local ok = pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_ON_PIID, indicator == "on")
    if ok then
        device:emit_event(indicatorLightControl.indicatorLight({value = indicator}))
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
    if not device:supports_capability_by_id(waterShortageStatus.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(fanLevelControl.fanLevel({value = "levelOne"}))
    device:emit_event(targetHumidityControl.targetHumidity({value = 50, unit = "%"}))
    device:emit_event(operatingStatus.operatingStatus({value = "idle"}))
    device:emit_event(indicatorLightControl.indicatorLight({value = "on"}))
    device:emit_event(alarmControl.alarm({value = "off"}))
    device:emit_event(tankFilledStatus.tankFilled({value = "filled"}))
    device:emit_event(waterShortageStatus.waterShortage({value = "normal"}))
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

local driver = Driver("miot-deerma-humidifier-990dw", {
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
        [fanLevelControl.ID] = {
            [fanLevelControl.commands.setFanLevel.NAME] = set_fan_level_handler
        },
        [targetHumidityControl.ID] = {
            [targetHumidityControl.commands.setTargetHumidity.NAME] = set_target_humidity_handler
        },
        [indicatorLightControl.ID] = {
            [indicatorLightControl.commands.setIndicatorLight.NAME] = set_indicator_light_handler
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
