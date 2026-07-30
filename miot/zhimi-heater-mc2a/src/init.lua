-- Mi Smart Space Heater S MC2A Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local countdownHoursCap = capabilities["concertmirror08464.zhimiHeaterMc2aCountdownHours"]
local buzzerCap = capabilities["concertmirror08464.zhimiHeaterMc2aBuzzer"]
local childLockCap = capabilities["concertmirror08464.zhimiHeaterMc2aChildLock"]
local indicatorLightCap = capabilities["concertmirror08464.zhimiHeaterMc2aIndicatorLight"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "zhimi-heater-mc2a"

-- MIoT model: zhimi.heater.mc2a
-- specModel: zhimi-mc2a
-- URN: urn:miot-spec-v2:device:heater:0000A01A:zhimi-mc2a:1
-- Source: python-miio miio.integrations.zhimi.heater.heater_miot, exact
-- zhimi.heater.mc2a entry in _MAPPINGS on class HeaterMiot(MiotDevice), so the
-- local path is get_properties / set_properties with siid/piid.
--
-- Heater service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, only value 0 (No Faults) in this spec, not exposed
--   piid=5 target-temperature, float, RW, 18..28 C, step 1
-- Countdown service (siid=3)
--   piid=1 countdown-time, uint32, RW, 0..12 hours, step 1
-- Environment service (siid=4)
--   piid=7 temperature, float, R, -30..100 C
-- Physical Control Locked service (siid=5)
--   piid=1 physical-controls-locked, bool, RW
-- Alarm service (siid=6)
--   piid=1 alarm/buzzer, bool, RW
-- Indicator Light service (siid=7)
--   piid=1 on, bool, RW. The python-miio entry copies mc2's piid=3 brightness,
--   which zhimi-mc2a:1 does not define, so this driver follows the exact spec.
-- Private service (siid=8)
--   piid=1 button-pressed, piid=8 hw-enable, piid=9 use-time,
--   piid=10 country-code, private/diagnostic, not exposed

local HEATER_SIID = 2
local POWER_PIID = 1
local TARGET_TEMPERATURE_PIID = 5

local COUNTDOWN_SIID = 3
local COUNTDOWN_TIME_PIID = 1

local ENVIRONMENT_SIID = 4
local TEMPERATURE_PIID = 7

local CHILD_LOCK_SIID = 5
local CHILD_LOCK_PIID = 1

local ALARM_SIID = 6
local ALARM_PIID = 1

local INDICATOR_SIID = 7
local INDICATOR_ON_PIID = 1

local TARGET_TEMPERATURE_MIN = 18
local TARGET_TEMPERATURE_MAX = 28
local TARGET_TEMPERATURE_STEP = 1

local COUNTDOWN_MIN = 0
local COUNTDOWN_MAX = 12

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

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function emit_heating_range(device)
    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpointRange({
        value = {
            minimum = TARGET_TEMPERATURE_MIN,
            maximum = TARGET_TEMPERATURE_MAX,
            step = TARGET_TEMPERATURE_STEP
        },
        unit = "C"
    }))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = HEATER_SIID, piid = POWER_PIID},
        {siid = HEATER_SIID, piid = TARGET_TEMPERATURE_PIID},
        {siid = COUNTDOWN_SIID, piid = COUNTDOWN_TIME_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_ON_PIID}
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
                end
            elseif siid == COUNTDOWN_SIID and piid == COUNTDOWN_TIME_PIID then
                device:emit_event(countdownHoursCap.countdownHours({value = value, unit = "h"}))
            elseif siid == ENVIRONMENT_SIID and piid == TEMPERATURE_PIID then
                device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(childLockCap.childLock({value = bool_to_st(value)}))
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(buzzerCap.buzzer({value = bool_to_st(value)}))
            elseif siid == INDICATOR_SIID and piid == INDICATOR_ON_PIID then
                device:emit_event(indicatorLightCap.indicatorLight({value = bool_to_st(value)}))
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

    local setpoint = clamp(math.floor(command.args.setpoint + 0.5), TARGET_TEMPERATURE_MIN, TARGET_TEMPERATURE_MAX)
    local ok = pcall(miot.set, device, ip, token, HEATER_SIID, TARGET_TEMPERATURE_PIID, setpoint)
    if ok then
        device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = setpoint, unit = "C"}))
    end
end

local function set_countdown_hours_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local hours = clamp(math.floor(command.args.countdownHours + 0.5), COUNTDOWN_MIN, COUNTDOWN_MAX)
    local ok = pcall(miot.set, device, ip, token, COUNTDOWN_SIID, COUNTDOWN_TIME_PIID, hours)
    if ok then
        device:emit_event(countdownHoursCap.countdownHours({value = hours, unit = "h"}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    local ok = pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, child_lock == "on")
    if ok then
        device:emit_event(childLockCap.childLock({value = child_lock}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local buzzer = command.args.buzzer
    local ok = pcall(miot.set, device, ip, token, ALARM_SIID, ALARM_PIID, buzzer == "on")
    if ok then
        device:emit_event(buzzerCap.buzzer({value = buzzer}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator = command.args.indicatorLight
    local ok = pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_ON_PIID, indicator == "on")
    if ok then
        device:emit_event(indicatorLightCap.indicatorLight({value = indicator}))
    end
end

local function refresh_handler(_, device, _)
    emit_heating_range(device)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(countdownHoursCap.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = TARGET_TEMPERATURE_MIN, unit = "C"}))
    emit_heating_range(device)
    device:emit_event(countdownHoursCap.countdownHours({value = 0, unit = "h"}))
    device:emit_event(childLockCap.childLock({value = "off"}))
    device:emit_event(buzzerCap.buzzer({value = "off"}))
    device:emit_event(indicatorLightCap.indicatorLight({value = "on"}))
end

local function device_init(_, device)
    ensure_profile(device)
    device:online()
    emit_heating_range(device)

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
    ensure_profile(device)
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

local driver = Driver("miot-zhimi-heater-mc2a", {
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
        [countdownHoursCap.ID] = {
            [countdownHoursCap.commands.setCountdownHours.NAME] = set_countdown_hours_handler
        },
        [childLockCap.ID] = {
            [childLockCap.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [buzzerCap.ID] = {
            [buzzerCap.commands.setBuzzer.NAME] = set_buzzer_handler
        },
        [indicatorLightCap.ID] = {
            [indicatorLightCap.commands.setIndicatorLight.NAME] = set_indicator_light_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
