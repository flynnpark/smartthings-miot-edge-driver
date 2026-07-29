-- Pinlo Humidifier SH01 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local modeControl = capabilities["concertmirror08464.pinloHumSh01Mode"]
local fanLevelControl = capabilities["concertmirror08464.pinloHumSh01FanLevel"]
local targetHumidityControl = capabilities["concertmirror08464.pinloHumSh01TargetHumidity"]
local heaterControl = capabilities["concertmirror08464.pinloHumSh01Heater"]
local waterShortageStatus = capabilities["concertmirror08464.pinloHumSh01WaterShortage"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "pinlo-humidifier-sh01"

-- MIoT model: pinlo.humidifier.sh01
-- specModel: pinlo-sh01
-- URN: urn:miot-spec-v2:device:humidifier:0000A00E:pinlo-sh01:1
--
-- Humidifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R enum: 0=noFaults, 1=lowWater
--   piid=3 mode, uint8, RW enum: 1=constantHumidity, 2=manual, 3=auto
--   piid=5 fan-level, uint8, RW enum: 1=levelOne, 2=levelTwo, 3=levelThree
--   piid=6 target-humidity, uint8, RW range 45..95 step 5, %
--   piid=8 heater, uint8, RW enum: 0=off, 1=on
-- Environment service (siid=3)
--   piid=1 relative-humidity, uint8, R, 0..100 %
--   piid=2 temperature, int8, R, celsius
-- multifunction service (siid=4): timer and internal values, not exposed

local HUMIDIFIER_SIID = 2
local POWER_PIID = 1
local FAULT_PIID = 2
local MODE_PIID = 3
local FAN_LEVEL_PIID = 5
local TARGET_HUMIDITY_PIID = 6
local HEATER_PIID = 8

local ENVIRONMENT_SIID = 3
local HUMIDITY_PIID = 1
local TEMPERATURE_PIID = 2

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [1] = "constantHumidity",
    [2] = "manual",
    [3] = "auto"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    constantHumidity = 1,
    manual = 2,
    auto = 3
}

local FAN_LEVEL_TO_ST = {
    [1] = "levelOne",
    [2] = "levelTwo",
    [3] = "levelThree"
}

local ST_TO_FAN_LEVEL = {
    levelOne = 1,
    levelTwo = 2,
    levelThree = 3
}

local TARGET_HUMIDITY_MIN = 45
local TARGET_HUMIDITY_MAX = 95
local TARGET_HUMIDITY_STEP = 5

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
        {siid = HUMIDIFIER_SIID, piid = MODE_PIID},
        {siid = HUMIDIFIER_SIID, piid = FAN_LEVEL_PIID},
        {siid = HUMIDIFIER_SIID, piid = TARGET_HUMIDITY_PIID},
        {siid = HUMIDIFIER_SIID, piid = HEATER_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID}
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
                    -- This model reports water shortage through the fault code.
                    device:emit_event(waterShortageStatus.waterShortage({value = value == 1 and "shortage" or "normal"}))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(modeControl.mode({value = mode}))
                    end
                elseif piid == FAN_LEVEL_PIID then
                    local level = FAN_LEVEL_TO_ST[value]
                    if level then
                        device:emit_event(fanLevelControl.fanLevel({value = level}))
                    end
                elseif piid == TARGET_HUMIDITY_PIID then
                    device:emit_event(targetHumidityControl.targetHumidity({value = value, unit = "%"}))
                elseif piid == HEATER_PIID then
                    device:emit_event(heaterControl.heater({value = value == 1 and "on" or "off"}))
                end
            elseif siid == ENVIRONMENT_SIID then
                if piid == HUMIDITY_PIID then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
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

local function set_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, POWER_PIID, true)
    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(modeControl.mode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
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
        device:emit_event(fanLevelControl.fanLevel({value = level}))
    end
end

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local target = tonumber(command.args.humidity)
    if not target then return end
    if target < TARGET_HUMIDITY_MIN or target > TARGET_HUMIDITY_MAX then return end

    -- The device accepts 45..95 in steps of 5, so snap the slider value.
    local value = math.floor(target / TARGET_HUMIDITY_STEP + 0.5) * TARGET_HUMIDITY_STEP
    if value < TARGET_HUMIDITY_MIN then value = TARGET_HUMIDITY_MIN end
    if value > TARGET_HUMIDITY_MAX then value = TARGET_HUMIDITY_MAX end

    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, TARGET_HUMIDITY_PIID, value)
    if ok then
        device:emit_event(targetHumidityControl.targetHumidity({value = value, unit = "%"}))
    end
end

local function set_heater_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local heater = command.args.heater
    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, HEATER_PIID, heater == "on" and 1 or 0)
    if ok then
        device:emit_event(heaterControl.heater({value = heater}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(heaterControl.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(modeControl.mode({value = "auto"}))
    device:emit_event(fanLevelControl.fanLevel({value = "levelOne"}))
    device:emit_event(targetHumidityControl.targetHumidity({value = 60, unit = "%"}))
    device:emit_event(heaterControl.heater({value = "off"}))
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

local driver = Driver("miot-pinlo-humidifier-sh01", {
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
        [modeControl.ID] = {
            [modeControl.commands.setMode.NAME] = set_mode_handler
        },
        [fanLevelControl.ID] = {
            [fanLevelControl.commands.setFanLevel.NAME] = set_fan_level_handler
        },
        [targetHumidityControl.ID] = {
            [targetHumidityControl.commands.setTargetHumidity.NAME] = set_target_humidity_handler
        },
        [heaterControl.ID] = {
            [heaterControl.commands.setHeater.NAME] = set_heater_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
