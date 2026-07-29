-- Xiaomi Water Heater YM03 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local operatingStatus = capabilities["concertmirror08464.xiaomiWhYm03Status"]
local modeControl = capabilities["concertmirror08464.xiaomiWhYm03Mode"]
local waterLevelStatus = capabilities["concertmirror08464.xiaomiWhYm03WaterLevel"]
local sterilizationControl = capabilities["concertmirror08464.xiaomiWhYm03Sterilize"]
local screenControl = capabilities["concertmirror08464.xiaomiWhYm03Screen"]
local filterLifeStatus = capabilities["concertmirror08464.xiaomiWhYm03FilterLife"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "xiaomi-water-heater-ym03"

-- MIoT model: xiaomi.waterheater.ym03
-- specModel: xiaomi-ym03
-- URN: urn:miot-spec-v2:device:water-heater:0000A02A:xiaomi-ym03:1
--
-- Water Heater service (siid=2)
--   piid=1 fault, uint32, R, raw code, not exposed
--   piid=2 target-temperature, uint8, RW range 30..80 celsius
--   piid=3 temperature, int8, R, celsius
--   piid=4 mode, uint8, RW enum: 0=single, 1=largeVolume
--   piid=5 status, uint8, R enum: 0=close, 1=keepWarm, 2=heating, 3=disinfect
--   piid=6 on, bool, RW
--   piid=8 water-level, uint8, R enum: 0..4 levels
--   piid=7 preheat timer, piid=9 anti-icing, piid=10 power consumption,
--     piid=11 staggered timer: auxiliary values, not exposed
-- Screen service (siid=3)
--   piid=2 brightness, uint8, RW enum: 0=levelOne, 1=levelTwo, 2=levelThree
-- Sterilization service (siid=4)
--   piid=1 on, bool, RW
--   piid=2 timer, piid=3 cycle, piid=4 start-time: schedule values, not exposed
-- Filter service (siid=5)
--   piid=1 filter-life-level, uint8, R, 0..100 %

local HEATER_SIID = 2
local TARGET_TEMPERATURE_PIID = 2
local TEMPERATURE_PIID = 3
local MODE_PIID = 4
local STATUS_PIID = 5
local POWER_PIID = 6
local WATER_LEVEL_PIID = 8

local SCREEN_SIID = 3
local SCREEN_BRIGHTNESS_PIID = 2

local STERILIZE_SIID = 4
local STERILIZE_ON_PIID = 1

local FILTER_SIID = 5
local FILTER_LIFE_PIID = 1

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [0] = "single",
    [1] = "largeVolume"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    single = 0,
    largeVolume = 1
}

local STATUS_TO_ST = {
    [0] = "close",
    [1] = "keepWarm",
    [2] = "heating",
    [3] = "disinfect"
}

local WATER_LEVEL_TO_ST = {
    [0] = "levelZero",
    [1] = "levelOne",
    [2] = "levelTwo",
    [3] = "levelThree",
    [4] = "levelFour"
}

local SCREEN_TO_ST = {
    [0] = "levelOne",
    [1] = "levelTwo",
    [2] = "levelThree"
}

local ST_TO_SCREEN = {
    levelOne = 0,
    levelTwo = 1,
    levelThree = 2
}

local TARGET_TEMPERATURE_MIN = 30
local TARGET_TEMPERATURE_MAX = 80

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
        {siid = HEATER_SIID, piid = POWER_PIID},
        {siid = HEATER_SIID, piid = TARGET_TEMPERATURE_PIID},
        {siid = HEATER_SIID, piid = TEMPERATURE_PIID},
        {siid = HEATER_SIID, piid = MODE_PIID},
        {siid = HEATER_SIID, piid = STATUS_PIID},
        {siid = HEATER_SIID, piid = WATER_LEVEL_PIID},
        {siid = SCREEN_SIID, piid = SCREEN_BRIGHTNESS_PIID},
        {siid = STERILIZE_SIID, piid = STERILIZE_ON_PIID},
        {siid = FILTER_SIID, piid = FILTER_LIFE_PIID}
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

            if siid == HEATER_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == TARGET_TEMPERATURE_PIID then
                    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = value, unit = "C"}))
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(modeControl.mode({value = mode}))
                    end
                elseif piid == STATUS_PIID then
                    local status = STATUS_TO_ST[value]
                    if status then
                        device:emit_event(operatingStatus.operatingStatus({value = status}))
                    end
                elseif piid == WATER_LEVEL_PIID then
                    local level = WATER_LEVEL_TO_ST[value]
                    if level then
                        device:emit_event(waterLevelStatus.waterLevel({value = level}))
                    end
                end
            elseif siid == SCREEN_SIID and piid == SCREEN_BRIGHTNESS_PIID then
                local brightness = SCREEN_TO_ST[value]
                if brightness then
                    device:emit_event(screenControl.screenBrightness({value = brightness}))
                end
            elseif siid == STERILIZE_SIID and piid == STERILIZE_ON_PIID then
                device:emit_event(sterilizationControl.sterilization({value = value and "on" or "off"}))
            elseif siid == FILTER_SIID and piid == FILTER_LIFE_PIID then
                device:emit_event(filterLifeStatus.filterLifeLevel({value = value, unit = "%"}))
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

    local ok = pcall(miot.set, device, ip, token, HEATER_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, HEATER_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_heating_setpoint_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local setpoint = tonumber(command.args.setpoint)
    if not setpoint then return end
    if setpoint < TARGET_TEMPERATURE_MIN or setpoint > TARGET_TEMPERATURE_MAX then return end

    local value = math.floor(setpoint + 0.5)
    local ok = pcall(miot.set, device, ip, token, HEATER_SIID, TARGET_TEMPERATURE_PIID, value)
    if ok then
        device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = value, unit = "C"}))
    end
end

local function set_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, HEATER_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(modeControl.mode({value = mode}))
    end
end

local function set_screen_brightness_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local brightness = command.args.screenBrightness
    local value = ST_TO_SCREEN[brightness]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, SCREEN_SIID, SCREEN_BRIGHTNESS_PIID, value)
    if ok then
        device:emit_event(screenControl.screenBrightness({value = brightness}))
    end
end

local function set_sterilization_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local sterilization = command.args.sterilization
    local ok = pcall(miot.set, device, ip, token, STERILIZE_SIID, STERILIZE_ON_PIID, sterilization == "on")
    if ok then
        device:emit_event(sterilizationControl.sterilization({value = sterilization}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(operatingStatus.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = 50, unit = "C"}))
    device:emit_event(operatingStatus.operatingStatus({value = "close"}))
    device:emit_event(modeControl.mode({value = "single"}))
    device:emit_event(waterLevelStatus.waterLevel({value = "levelZero"}))
    device:emit_event(sterilizationControl.sterilization({value = "off"}))
    device:emit_event(screenControl.screenBrightness({value = "levelTwo"}))
    device:emit_event(filterLifeStatus.filterLifeLevel({value = 100, unit = "%"}))
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

local driver = Driver("miot-xiaomi-water-heater-ym03", {
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
        [capabilities.thermostatHeatingSetpoint.ID] = {
            [capabilities.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] = set_heating_setpoint_handler
        },
        [modeControl.ID] = {
            [modeControl.commands.setMode.NAME] = set_mode_handler
        },
        [screenControl.ID] = {
            [screenControl.commands.setScreenBrightness.NAME] = set_screen_brightness_handler
        },
        [sterilizationControl.ID] = {
            [sterilizationControl.commands.setSterilization.NAME] = set_sterilization_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
