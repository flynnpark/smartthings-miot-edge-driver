-- Xiaomi Water Heater YM02 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local statusCap = capabilities["concertmirror08464.xiaomiWhYm02Status"]
local modeCap = capabilities["concertmirror08464.xiaomiWhYm02Mode"]
local waterLevelCap = capabilities["concertmirror08464.xiaomiWhYm02WaterLevel"]
local antiIcingCap = capabilities["concertmirror08464.xiaomiWhYm02AntiIcing"]
local sterilizeCap = capabilities["concertmirror08464.xiaomiWhYm02Sterilize"]
local sterilizeTimerCap = capabilities["concertmirror08464.xiaomiWhYm02SterilizeTimer"]
local sterilizeCycleCap = capabilities["concertmirror08464.xiaomiWhYm02SterilizeCycle"]
local screenCap = capabilities["concertmirror08464.xiaomiWhYm02Screen"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "xiaomi-water-heater-ym02"

-- MIoT model: xiaomi.waterheater.ym02
-- specModel: xiaomi-ym02
-- URN: urn:miot-spec-v2:device:water-heater:0000A02A:xiaomi-ym02:1
--
-- Water Heater service (siid=2)
--   piid=1 fault, uint32, R, raw code, not exposed
--   piid=2 target-temperature, float, RW range 30..75, celsius
--   piid=3 temperature, float, R, celsius (water temperature)
--   piid=4 frequency-level, uint8, RW enum: 0=quick, 1=eco
--   piid=5 status, uint8, R enum: 0=close, 1=keepwarm, 2=heating, 3=disinfect
--   piid=6 on, bool, RW
--   piid=8 water-level, uint8, R enum: 0..4
--   piid=9 anti-icing-status, uint8, R enum: 0=normal, 1=antifreeze
--   piid=7 preheat-timer and piid=11 staggered-timer carry schedule strings and
--     piid=10 power-consumption is a cumulative counter, so none are exposed
-- Screen service (siid=3)
--   piid=2 brightness, uint8, RW enum: 0..2 shown as level 1..3
-- Sterilization service (siid=4)
--   piid=1 on, bool, RW
--   piid=2 timer-on, bool, RW
--   piid=3 cycle, uint8, RW range 1..120 hours
--   piid=4 start-time is a minute-of-day schedule value, not exposed

local HEATER_SIID = 2
local TARGET_TEMPERATURE_PIID = 2
local TEMPERATURE_PIID = 3
local MODE_PIID = 4
local STATUS_PIID = 5
local POWER_PIID = 6
local WATER_LEVEL_PIID = 8
local ANTI_ICING_PIID = 9

local SCREEN_SIID = 3
local BRIGHTNESS_PIID = 2

local STERILIZE_SIID = 4
local STERILIZE_ON_PIID = 1
local STERILIZE_TIMER_PIID = 2
local STERILIZE_CYCLE_PIID = 3

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [0] = "quick",
    [1] = "eco"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    quick = 0,
    eco = 1
}

local STATUS_TO_ST = {
    [0] = "closed",
    [1] = "keepWarm",
    [2] = "heating",
    [3] = "disinfect"
}

local WATER_LEVEL_TO_ST = {
    [0] = "level0",
    [1] = "level1",
    [2] = "level2",
    [3] = "level3",
    [4] = "level4"
}

local ANTI_ICING_TO_ST = {
    [0] = "normal",
    [1] = "antifreeze"
}

local BRIGHTNESS_TO_ST = {
    [0] = "level1",
    [1] = "level2",
    [2] = "level3"
}

local ST_TO_BRIGHTNESS = {
    level1 = 0,
    level2 = 1,
    level3 = 2
}

local TARGET_TEMPERATURE_MIN = 30
local TARGET_TEMPERATURE_MAX = 75
local STERILIZE_CYCLE_MIN = 1
local STERILIZE_CYCLE_MAX = 120

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(statusCap.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
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
        {siid = HEATER_SIID, piid = TARGET_TEMPERATURE_PIID},
        {siid = HEATER_SIID, piid = TEMPERATURE_PIID},
        {siid = HEATER_SIID, piid = MODE_PIID},
        {siid = HEATER_SIID, piid = STATUS_PIID},
        {siid = HEATER_SIID, piid = POWER_PIID},
        {siid = HEATER_SIID, piid = WATER_LEVEL_PIID},
        {siid = HEATER_SIID, piid = ANTI_ICING_PIID},
        {siid = SCREEN_SIID, piid = BRIGHTNESS_PIID},
        {siid = STERILIZE_SIID, piid = STERILIZE_ON_PIID},
        {siid = STERILIZE_SIID, piid = STERILIZE_TIMER_PIID},
        {siid = STERILIZE_SIID, piid = STERILIZE_CYCLE_PIID}
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
                if piid == TARGET_TEMPERATURE_PIID then
                    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({
                        value = value,
                        unit = "C"
                    }))
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(modeCap.heatMode({value = mode}))
                    end
                elseif piid == STATUS_PIID then
                    local status = STATUS_TO_ST[value]
                    if status then
                        device:emit_event(statusCap.heaterStatus({value = status}))
                    end
                elseif piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(bool_to_st(value)))
                elseif piid == WATER_LEVEL_PIID then
                    local level = WATER_LEVEL_TO_ST[value]
                    if level then
                        device:emit_event(waterLevelCap.waterLevel({value = level}))
                    end
                elseif piid == ANTI_ICING_PIID then
                    local state = ANTI_ICING_TO_ST[value]
                    if state then
                        device:emit_event(antiIcingCap.antiIcing({value = state}))
                    end
                end
            elseif siid == SCREEN_SIID and piid == BRIGHTNESS_PIID then
                local brightness = BRIGHTNESS_TO_ST[value]
                if brightness then
                    device:emit_event(screenCap.screenBrightness({value = brightness}))
                end
            elseif siid == STERILIZE_SIID then
                if piid == STERILIZE_ON_PIID then
                    device:emit_event(sterilizeCap.sterilize({value = bool_to_st(value)}))
                elseif piid == STERILIZE_TIMER_PIID then
                    device:emit_event(sterilizeTimerCap.sterilizeTimer({value = bool_to_st(value)}))
                elseif piid == STERILIZE_CYCLE_PIID then
                    device:emit_event(sterilizeCycleCap.sterilizeCycle({value = value, unit = "h"}))
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

    local value = math.floor(setpoint + 0.5)
    if value < TARGET_TEMPERATURE_MIN or value > TARGET_TEMPERATURE_MAX then return end

    local ok = pcall(miot.set, device, ip, token, HEATER_SIID, TARGET_TEMPERATURE_PIID, value)
    if ok then
        device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = value, unit = "C"}))
    end
end

local function set_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.heatMode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, HEATER_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(modeCap.heatMode({value = mode}))
    end
end

local function set_screen_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local brightness = command.args.screenBrightness
    local value = ST_TO_BRIGHTNESS[brightness]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, SCREEN_SIID, BRIGHTNESS_PIID, value)
    if ok then
        device:emit_event(screenCap.screenBrightness({value = brightness}))
    end
end

local function set_sterilize_cycle_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.sterilizeCycle)
    if not requested then return end

    local value = math.max(STERILIZE_CYCLE_MIN, math.min(STERILIZE_CYCLE_MAX, math.floor(requested + 0.5)))
    local ok = pcall(miot.set, device, ip, token, STERILIZE_SIID, STERILIZE_CYCLE_PIID, value)
    if ok then
        device:emit_event(sterilizeCycleCap.sterilizeCycle({value = value, unit = "h"}))
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

local set_sterilize_handler = make_bool_handler(STERILIZE_SIID, STERILIZE_ON_PIID, sterilizeCap, "sterilize", "sterilize")
local set_sterilize_timer_handler = make_bool_handler(STERILIZE_SIID, STERILIZE_TIMER_PIID, sterilizeTimerCap, "sterilizeTimer", "sterilizeTimer")

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:online()
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(statusCap.heaterStatus({value = "closed"}))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = 50, unit = "C"}))
    device:emit_event(modeCap.heatMode({value = "eco"}))
    device:emit_event(waterLevelCap.waterLevel({value = "level0"}))
    device:emit_event(antiIcingCap.antiIcing({value = "normal"}))
    device:emit_event(sterilizeCap.sterilize({value = "off"}))
    device:emit_event(sterilizeTimerCap.sterilizeTimer({value = "off"}))
    device:emit_event(sterilizeCycleCap.sterilizeCycle({value = 24, unit = "h"}))
    device:emit_event(screenCap.screenBrightness({value = "level2"}))
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

local driver = Driver("miot-xiaomi-water-heater-ym02", {
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
        [modeCap.ID] = {
            [modeCap.commands.setHeatMode.NAME] = set_mode_handler
        },
        [sterilizeCap.ID] = {
            [sterilizeCap.commands.setSterilize.NAME] = set_sterilize_handler
        },
        [sterilizeTimerCap.ID] = {
            [sterilizeTimerCap.commands.setSterilizeTimer.NAME] = set_sterilize_timer_handler
        },
        [sterilizeCycleCap.ID] = {
            [sterilizeCycleCap.commands.setSterilizeCycle.NAME] = set_sterilize_cycle_handler
        },
        [screenCap.ID] = {
            [screenCap.commands.setScreenBrightness.NAME] = set_screen_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
