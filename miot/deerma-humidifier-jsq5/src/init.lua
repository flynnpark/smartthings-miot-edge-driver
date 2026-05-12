-- Deerma Humidifier JSQ5 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local controls = capabilities["concertmirror08464.deermaHumidifierJsq5Controls"]
local stats = capabilities["concertmirror08464.deermaHumidifierJsq5Stats"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60

-- MIoT model: deerma.humidifier.jsq5
-- specModel: deerma-jsq5
-- URN: urn:miot-spec-v2:device:humidifier:0000A00E:deerma-jsq5:1
--
-- Humidifier service (siid=2)
--   piid=1 power, bool, RW
--   piid=2 fault, enum, R: 0=noFaults, 1=insufficientWater, 2=waterSeparation
--   piid=5 fan-level, enum, RW: 1=level1, 2=level2, 3=level3, 4=humidity
--   piid=6 target-humidity, uint8, RW, 40..80 %, step 1
-- Environment service (siid=3)
--   piid=1 relative-humidity, uint8, R, 0..100 %
--   piid=7 temperature, int8, R, C
-- Alarm service (siid=5)
--   piid=1 alarm, bool, RW
-- Indicator light service (siid=6)
--   piid=1 on, bool, RW
-- Custom service (siid=7)
--   piid=1 water-shortage-fault, bool, R
--   piid=2 the-tank-filed, bool, R

local HUMIDIFIER_SIID = 2
local POWER_PIID = 1
local FAULT_PIID = 2
local FAN_LEVEL_PIID = 5
local TARGET_HUMIDITY_PIID = 6

local ENVIRONMENT_SIID = 3
local HUMIDITY_PIID = 1
local TEMPERATURE_PIID = 7

local ALARM_SIID = 5
local ALARM_PIID = 1

local INDICATOR_LIGHT_SIID = 6
local INDICATOR_LIGHT_PIID = 1

local CUSTOM_SIID = 7
local WATER_SHORTAGE_PIID = 1
local TANK_FILLED_PIID = 2

local FAN_LEVEL_TO_ST = {
    [1] = "level1",
    [2] = "level2",
    [3] = "level3",
    [4] = "humidity"
}

local ST_TO_FAN_LEVEL = {
    level1 = 1,
    level2 = 2,
    level3 = 3,
    humidity = 4
}

local FAULT_TO_ST = {
    [0] = "noFaults",
    [1] = "insufficientWater",
    [2] = "waterSeparation"
}

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = HUMIDIFIER_SIID, piid = POWER_PIID},
        {siid = HUMIDIFIER_SIID, piid = FAULT_PIID},
        {siid = HUMIDIFIER_SIID, piid = FAN_LEVEL_PIID},
        {siid = HUMIDIFIER_SIID, piid = TARGET_HUMIDITY_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = INDICATOR_LIGHT_SIID, piid = INDICATOR_LIGHT_PIID},
        {siid = CUSTOM_SIID, piid = WATER_SHORTAGE_PIID},
        {siid = CUSTOM_SIID, piid = TANK_FILLED_PIID}
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
                elseif piid == FAULT_PIID then
                    local fault = FAULT_TO_ST[value]
                    if fault then
                        device:emit_event(stats.fault({value = fault}))
                    end
                elseif piid == FAN_LEVEL_PIID then
                    local level = FAN_LEVEL_TO_ST[value]
                    if level then
                        device:emit_event(controls.fanLevel({value = level}))
                    end
                elseif piid == TARGET_HUMIDITY_PIID then
                    device:emit_event(controls.targetHumidity({value = value, unit = "%"}))
                end
            elseif siid == ENVIRONMENT_SIID then
                if piid == HUMIDITY_PIID then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                end
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(controls.alarm({value = value and "on" or "off"}))
            elseif siid == INDICATOR_LIGHT_SIID and piid == INDICATOR_LIGHT_PIID then
                device:emit_event(controls.indicatorLight({value = value and "on" or "off"}))
            elseif siid == CUSTOM_SIID then
                if piid == WATER_SHORTAGE_PIID then
                    device:emit_event(stats.waterShortageFault({value = value and "on" or "off"}))
                elseif piid == TANK_FILLED_PIID then
                    device:emit_event(stats.tankFilled({value = value and "on" or "off"}))
                end
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

    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, FAN_LEVEL_PIID, value)
    if ok then
        device:emit_event(controls.fanLevel({value = level}))
    end
end

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local humidity = math.max(40, math.min(80, command.args.humidity))
    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, TARGET_HUMIDITY_PIID, humidity)
    if ok then
        device:emit_event(controls.targetHumidity({value = humidity, unit = "%"}))
    end
end

local function set_alarm_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local alarm = command.args.alarm
    local ok = pcall(miot.set, device, ip, token, ALARM_SIID, ALARM_PIID, alarm == "on")
    if ok then
        device:emit_event(controls.alarm({value = alarm}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator = command.args.indicatorLight
    local ok = pcall(miot.set, device, ip, token, INDICATOR_LIGHT_SIID, INDICATOR_LIGHT_PIID, indicator == "on")
    if ok then
        device:emit_event(controls.indicatorLight({value = indicator}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(controls.fanLevel({value = "level1"}))
    device:emit_event(controls.targetHumidity({value = 40, unit = "%"}))
    device:emit_event(controls.alarm({value = "off"}))
    device:emit_event(controls.indicatorLight({value = "off"}))
    device:emit_event(stats.fault({value = "noFaults"}))
    device:emit_event(stats.waterShortageFault({value = "off"}))
    device:emit_event(stats.tankFilled({value = "off"}))
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

local driver = Driver("miot-deerma-humidifier-jsq5", {
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
        [controls.ID] = {
            [controls.commands.setFanLevel.NAME] = set_fan_level_handler,
            [controls.commands.setTargetHumidity.NAME] = set_target_humidity_handler,
            [controls.commands.setAlarm.NAME] = set_alarm_handler,
            [controls.commands.setIndicatorLight.NAME] = set_indicator_light_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
