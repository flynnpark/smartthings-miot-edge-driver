-- Mi Smart Space Heater S Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local controlsCountdownHours = capabilities["concertmirror08464.zhimiHeaterMc2CountdownHours"]
local controlsFaultCode = capabilities["concertmirror08464.zhimiHeaterMc2FaultCode"]
local controlsBuzzer = capabilities["concertmirror08464.zhimiHeaterMc2Buzzer"]
local controlsChildLock = capabilities["concertmirror08464.zhimiHeaterMc2ChildLock"]
local controlsIndicatorLight = capabilities["concertmirror08464.zhimiHeaterMc2IndicatorLight"]
local controlsFault = capabilities["concertmirror08464.zhimiHeaterMc2Fault"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60

-- MIoT model: zhimi.heater.mc2
-- specModel: zhimi-mc2
-- URN: urn:miot-spec-v2:device:heater:0000A01A:zhimi-mc2:1
--
-- Heater service (siid=2)
--   piid=1 power, bool, RW
--   piid=2 fault, uint8, R, 0..255; 0=noFaults, nonzero=fault
--   piid=5 target-temperature, float, RW, 18..28 C, step 1
-- Countdown service (siid=3)
--   piid=1 countdown-time, uint32, RW, 0..12 hours, step 1
-- Environment service (siid=4)
--   piid=7 temperature, float, R, -30..100 C, step 0.1
-- Physical Control Locked service (siid=5)
--   piid=1 physical-controls-locked, bool, RW
-- Alarm service (siid=6)
--   piid=1 alarm/buzzer, bool, RW
-- Indicator Light service (siid=7)
--   piid=3 brightness, uint8, RW, 0=bright, 1=off
-- Private service (siid=8)
--   piid=8 hw-enable, piid=9 use-time, piid=10 country-code, private/diagnostic, not exposed

local HEATER_SIID = 2
local POWER_PIID = 1
local FAULT_PIID = 2
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
local INDICATOR_BRIGHTNESS_PIID = 3

local TARGET_TEMPERATURE_MIN = 18
local TARGET_TEMPERATURE_MAX = 28
local TARGET_TEMPERATURE_STEP = 1

local COUNTDOWN_MIN = 0
local COUNTDOWN_MAX = 12
local COUNTDOWN_STEP = 1

local INDICATOR_TO_ST = {
    [0] = "bright",
    [1] = "off"
}

local ST_TO_INDICATOR = {
    bright = 0,
    off = 1
}

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

local function emit_countdown_range(device)
    device:emit_event(controlsCountdownHours.countdownHoursRange({
        value = {
            minimum = COUNTDOWN_MIN,
            maximum = COUNTDOWN_MAX,
            step = COUNTDOWN_STEP
        },
        unit = "h"
    }))
end

local function emit_fault(device, value)
    local fault = value == 0 and "noFaults" or "fault"
    device:emit_event(controlsFault.fault({value = fault}))
    device:emit_event(controlsFaultCode.faultCode({value = value}))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = HEATER_SIID, piid = POWER_PIID},
        {siid = HEATER_SIID, piid = FAULT_PIID},
        {siid = HEATER_SIID, piid = TARGET_TEMPERATURE_PIID},
        {siid = COUNTDOWN_SIID, piid = COUNTDOWN_TIME_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_BRIGHTNESS_PIID}
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
                elseif piid == FAULT_PIID then
                    emit_fault(device, value)
                elseif piid == TARGET_TEMPERATURE_PIID then
                    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = value, unit = "C"}))
                end
            elseif siid == COUNTDOWN_SIID and piid == COUNTDOWN_TIME_PIID then
                device:emit_event(controlsCountdownHours.countdownHours({value = value, unit = "h"}))
            elseif siid == ENVIRONMENT_SIID and piid == TEMPERATURE_PIID then
                device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(controlsChildLock.childLock({value = bool_to_st(value)}))
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(controlsBuzzer.buzzer({value = bool_to_st(value)}))
            elseif siid == INDICATOR_SIID and piid == INDICATOR_BRIGHTNESS_PIID then
                local indicator = INDICATOR_TO_ST[value]
                if indicator then
                    device:emit_event(controlsIndicatorLight.indicatorLight({value = indicator}))
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
        device:emit_event(controlsCountdownHours.countdownHours({value = hours, unit = "h"}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    local ok = pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, child_lock == "on")
    if ok then
        device:emit_event(controlsChildLock.childLock({value = child_lock}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local buzzer = command.args.buzzer
    local ok = pcall(miot.set, device, ip, token, ALARM_SIID, ALARM_PIID, buzzer == "on")
    if ok then
        device:emit_event(controlsBuzzer.buzzer({value = buzzer}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator = command.args.indicatorLight
    local value = ST_TO_INDICATOR[indicator]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_BRIGHTNESS_PIID, value)
    if ok then
        device:emit_event(controlsIndicatorLight.indicatorLight({value = indicator}))
    end
end

local function refresh_handler(_, device, _)
    emit_heating_range(device)
    emit_countdown_range(device)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(controlsCountdownHours.ID, "main") then
        device:try_update_metadata({profile = "zhimi-heater-mc2"})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = TARGET_TEMPERATURE_MIN, unit = "C"}))
    emit_heating_range(device)
    device:emit_event(controlsCountdownHours.countdownHours({value = 0, unit = "h"}))
    emit_countdown_range(device)
    device:emit_event(controlsChildLock.childLock({value = "off"}))
    device:emit_event(controlsBuzzer.buzzer({value = "off"}))
    device:emit_event(controlsIndicatorLight.indicatorLight({value = "bright"}))
    emit_fault(device, 0)
end

local function device_init(_, device)
    ensure_profile(device)
    device:online()
    emit_heating_range(device)
    emit_countdown_range(device)

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

local driver = Driver("miot-zhimi-heater-mc2", {
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
        [controlsCountdownHours.ID] = {
            [controlsCountdownHours.commands.setCountdownHours.NAME] = set_countdown_hours_handler
        },
        [controlsChildLock.ID] = {
            [controlsChildLock.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [controlsBuzzer.ID] = {
            [controlsBuzzer.commands.setBuzzer.NAME] = set_buzzer_handler
        },
        [controlsIndicatorLight.ID] = {
            [controlsIndicatorLight.commands.setIndicatorLight.NAME] = set_indicator_light_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
