-- Xiaomi Kettle V20 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local statusCap = capabilities["concertmirror08464.xiaomiKettleV20Status"]
local keepWarmCap = capabilities["concertmirror08464.xiaomiKettleV20KeepWarm"]
local warmTempCap = capabilities["concertmirror08464.xiaomiKettleV20WarmTemp"]
local warmTimeCap = capabilities["concertmirror08464.xiaomiKettleV20WarmTime"]
local liftedCap = capabilities["concertmirror08464.xiaomiKettleV20Lifted"]
local noDisturbCap = capabilities["concertmirror08464.xiaomiKettleV20NoDisturb"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "xiaomi-kettle-v20"

-- MIoT model: xiaomi.kettle.v20
-- specModel: xiaomi-v20
-- URN: urn:miot-spec-v2:device:kettle:0000A009:xiaomi-v20:1
--
-- Kettle service (siid=2)
--   piid=1 status, uint8, R enum: 0=idle, 1=heating, 2=boiling,
--     3=cooling down, 4=keep warm
--   piid=2 fault, uint8, R, raw code, not exposed
--   piid=3 temperature, int8, R, celsius (water temperature)
--   piid=4 target-temperature, uint8, RW range 40..99, celsius
--   piid=5 auto-keep-warm, bool, RW
--   piid=6 keep-warm-temperature, uint8, RW range 0..100, celsius
--   piid=7 on, bool, RW
-- No Disturb service (siid=6)
--   piid=1 no-disturb, bool, RW
-- Function service (siid=3)
--   piid=1 keep-warm-time, uint16, RW range 60..1440 minutes
--   piid=7 kettle-lifting, bool, R
--   piid=2 custom-knob-temp, piid=4 lift-remember-temp, piid=5/6 reminders,
--     piid=8 extended-mode, piid=10 warming-time, piid=11 target-mode, and
--     piid=12/13 heat and boil mode blobs are app preferences or opaque
--     vendor strings, so none of them are exposed
--   aiid=1 stop-work duplicates writing the power property to false
-- Knob Setting service (siid=4) and Local Timing service (siid=5) store button
--   presets and schedules rather than live device state
--
-- Heating starts only when the user writes the power property, so the target
-- temperature is a setting rather than an implicit start command.

local KETTLE_SIID = 2
local STATUS_PIID = 1
local TEMPERATURE_PIID = 3
local TARGET_TEMPERATURE_PIID = 4
local AUTO_KEEP_WARM_PIID = 5
local KEEP_WARM_TEMPERATURE_PIID = 6
local POWER_PIID = 7

local FUNCTION_SIID = 3
local KEEP_WARM_TIME_PIID = 1
local LIFTING_PIID = 7

local NO_DISTURB_SIID = 6
local NO_DISTURB_PIID = 1

-- MIoT -> SmartThings
local STATUS_TO_ST = {
    [0] = "idle",
    [1] = "heating",
    [2] = "boiling",
    [3] = "cooling",
    [4] = "keepWarm"
}

local TARGET_TEMPERATURE_MIN = 40
local TARGET_TEMPERATURE_MAX = 99
local KEEP_WARM_TIME_MIN = 60
local KEEP_WARM_TIME_MAX = 1440

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
        {siid = KETTLE_SIID, piid = STATUS_PIID},
        {siid = KETTLE_SIID, piid = TEMPERATURE_PIID},
        {siid = KETTLE_SIID, piid = TARGET_TEMPERATURE_PIID},
        {siid = KETTLE_SIID, piid = AUTO_KEEP_WARM_PIID},
        {siid = KETTLE_SIID, piid = KEEP_WARM_TEMPERATURE_PIID},
        {siid = KETTLE_SIID, piid = POWER_PIID},
        {siid = FUNCTION_SIID, piid = KEEP_WARM_TIME_PIID},
        {siid = FUNCTION_SIID, piid = LIFTING_PIID},
        {siid = NO_DISTURB_SIID, piid = NO_DISTURB_PIID}
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

            if siid == KETTLE_SIID then
                if piid == STATUS_PIID then
                    local status = STATUS_TO_ST[value]
                    if status then
                        device:emit_event(statusCap.kettleStatus({value = status}))
                    end
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == TARGET_TEMPERATURE_PIID then
                    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({
                        value = value,
                        unit = "C"
                    }))
                elseif piid == AUTO_KEEP_WARM_PIID then
                    device:emit_event(keepWarmCap.autoKeepWarm({value = bool_to_st(value)}))
                elseif piid == KEEP_WARM_TEMPERATURE_PIID then
                    device:emit_event(warmTempCap.keepWarmTemperature({value = value, unit = "C"}))
                elseif piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(bool_to_st(value)))
                end
            elseif siid == FUNCTION_SIID then
                if piid == KEEP_WARM_TIME_PIID then
                    device:emit_event(warmTimeCap.keepWarmTime({value = value, unit = "min"}))
                elseif piid == LIFTING_PIID then
                    device:emit_event(liftedCap.lifted({value = value and "yes" or "no"}))
                end
            elseif siid == NO_DISTURB_SIID and piid == NO_DISTURB_PIID then
                device:emit_event(noDisturbCap.noDisturb({value = bool_to_st(value)}))
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

    local ok = pcall(miot.set, device, ip, token, KETTLE_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, KETTLE_SIID, POWER_PIID, false)
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

    local ok = pcall(miot.set, device, ip, token, KETTLE_SIID, TARGET_TEMPERATURE_PIID, value)
    if ok then
        device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = value, unit = "C"}))
    end
end

local function set_warm_temp_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.keepWarmTemperature)
    if not requested then return end

    local value = math.max(0, math.min(100, math.floor(requested + 0.5)))
    local ok = pcall(miot.set, device, ip, token, KETTLE_SIID, KEEP_WARM_TEMPERATURE_PIID, value)
    if ok then
        device:emit_event(warmTempCap.keepWarmTemperature({value = value, unit = "C"}))
    end
end

local function set_warm_time_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.keepWarmTime)
    if not requested then return end

    local value = math.max(KEEP_WARM_TIME_MIN, math.min(KEEP_WARM_TIME_MAX, math.floor(requested + 0.5)))
    local ok = pcall(miot.set, device, ip, token, FUNCTION_SIID, KEEP_WARM_TIME_PIID, value)
    if ok then
        device:emit_event(warmTimeCap.keepWarmTime({value = value, unit = "min"}))
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

local set_keep_warm_handler = make_bool_handler(KETTLE_SIID, AUTO_KEEP_WARM_PIID, keepWarmCap, "autoKeepWarm", "autoKeepWarm")
local set_no_disturb_handler = make_bool_handler(NO_DISTURB_SIID, NO_DISTURB_PIID, noDisturbCap, "noDisturb", "noDisturb")

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:online()
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(statusCap.kettleStatus({value = "idle"}))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = 80, unit = "C"}))
    device:emit_event(keepWarmCap.autoKeepWarm({value = "off"}))
    device:emit_event(warmTempCap.keepWarmTemperature({value = 55, unit = "C"}))
    device:emit_event(warmTimeCap.keepWarmTime({value = 720, unit = "min"}))
    device:emit_event(liftedCap.lifted({value = "no"}))
    device:emit_event(noDisturbCap.noDisturb({value = "off"}))
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

local driver = Driver("miot-xiaomi-kettle-v20", {
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
        [keepWarmCap.ID] = {
            [keepWarmCap.commands.setAutoKeepWarm.NAME] = set_keep_warm_handler
        },
        [warmTempCap.ID] = {
            [warmTempCap.commands.setKeepWarmTemperature.NAME] = set_warm_temp_handler
        },
        [warmTimeCap.ID] = {
            [warmTimeCap.commands.setKeepWarmTime.NAME] = set_warm_time_handler
        },
        [noDisturbCap.ID] = {
            [noDisturbCap.commands.setNoDisturb.NAME] = set_no_disturb_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
