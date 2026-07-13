-- Xiaomi Dehumidifier 13L Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local controlsMode = capabilities["concertmirror08464.xiaomiDehum13lMode"]
local controlsTargetHumidity = capabilities["concertmirror08464.xiaomiDehum13lTargetHumidity"]
local controlsChildLock = capabilities["concertmirror08464.xiaomiDehum13lChildLock"]
local controlsIndicatorLight = capabilities["concertmirror08464.xiaomiDehum13lIndicatorLight"]
local controlsAlarm = capabilities["concertmirror08464.xiaomiDehum13lAlarm"]
local controlsDryAfterOff = capabilities["concertmirror08464.xiaomiDehum13lDryAfterOff"]
local controlsResetFilter = capabilities["concertmirror08464.xiaomiDehum13lResetFilter"]
local statusTankStatus = capabilities["concertmirror08464.xiaomiDehum13lTankStatus"]
local statusFilterStatus = capabilities["concertmirror08464.xiaomiDehum13lFilterStatus"]
local statusFault = capabilities["concertmirror08464.xiaomiDehum13lFault"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60

-- MIoT model: xiaomi.derh.13l
-- specModel: xiaomi-13l
-- URN: urn:miot-spec-v2:device:dehumidifier:0000A02D:xiaomi-13l:2
--
-- Dehumidifier service (siid=2)
--   piid=1 power, bool, RW
--   piid=2 fault, uint8, R: 0=noFaults, 1=waterFull, 2=sensorFault1,
--     3=sensorFault2, 4=communicationFault1, 5=filterClean,
--     6=defrost, 7=fanMotor, 8=overload, 9=lackOfRefrigerant
--   piid=3 mode, uint8, RW: 0=smart, 1=sleep, 2=clothesDrying
--   piid=5 target-humidity, uint8, RW, 30..70 %, step 1
-- Environment service (siid=3)
--   piid=1 relative-humidity, uint8, R, 0..100 %
--   piid=2 temperature, float, R, celsius
-- Alarm service (siid=4)
--   piid=1 alarm, bool, RW
-- Indicator Light service (siid=5)
--   piid=1 on, bool, RW
--   piid=2 mode, uint8, RW: 0=off, 1=half, 2=full
-- Physical Control Locked service (siid=6)
--   piid=1 physical-controls-locked, bool, RW
-- dm-service (siid=7)
--   piid=1 dry-after-off, bool, RW
--   piid=2 dry-left-time, uint16, R, seconds, diagnostic, not exposed
--   piid=3 is-warming-up, bool, R, diagnostic, not exposed
--   aiid=3 reset-filter, action
--   event aiid=1 tank-full, reflected through fault/tankStatus polling

local DEHUMIDIFIER_SIID = 2
local POWER_PIID = 1
local FAULT_PIID = 2
local MODE_PIID = 3
local TARGET_HUMIDITY_PIID = 5

local ENVIRONMENT_SIID = 3
local HUMIDITY_PIID = 1
local TEMPERATURE_PIID = 2

local ALARM_SIID = 4
local ALARM_PIID = 1

local INDICATOR_SIID = 5
local INDICATOR_ON_PIID = 1
local INDICATOR_MODE_PIID = 2

local CHILD_LOCK_SIID = 6
local CHILD_LOCK_PIID = 1

local DM_SERVICE_SIID = 7
local DRY_AFTER_OFF_PIID = 1
local RESET_FILTER_AIID = 3

local MODE_TO_ST = {
    [0] = "smart",
    [1] = "sleep",
    [2] = "clothesDrying"
}

local ST_TO_MODE = {
    smart = 0,
    sleep = 1,
    clothesDrying = 2
}

local FAULT_TO_ST = {
    [0] = "noFaults",
    [1] = "waterFull",
    [2] = "sensorFault1",
    [3] = "sensorFault2",
    [4] = "communicationFault1",
    [5] = "filterClean",
    [6] = "defrost",
    [7] = "fanMotor",
    [8] = "overload",
    [9] = "lackOfRefrigerant"
}

local INDICATOR_MODE_TO_ST = {
    [0] = "off",
    [1] = "half",
    [2] = "full"
}

local ST_TO_INDICATOR_MODE = {
    half = 1,
    full = 2
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

local function emit_fault(device, value)
    local fault = FAULT_TO_ST[value]
    if fault then
        device:emit_event(statusFault.fault({value = fault}))
        device:emit_event(statusTankStatus.tankStatus({value = fault == "waterFull" and "full" or "normal"}))
        device:emit_event(statusFilterStatus.filterStatus({value = fault == "filterClean" and "cleanRequired" or "normal"}))
    end
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = DEHUMIDIFIER_SIID, piid = POWER_PIID},
        {siid = DEHUMIDIFIER_SIID, piid = FAULT_PIID},
        {siid = DEHUMIDIFIER_SIID, piid = MODE_PIID},
        {siid = DEHUMIDIFIER_SIID, piid = TARGET_HUMIDITY_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_ON_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_MODE_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = DM_SERVICE_SIID, piid = DRY_AFTER_OFF_PIID}
    }

    local ok, response = pcall(miot.gets, device, ip, token, properties)
    if not ok or not response or not response.result then
        return
    end

    local indicator_on = nil
    local indicator_mode = nil

    for _, result in ipairs(response.result) do
        if result.code == 0 then
            local siid = result.siid
            local piid = result.piid
            local value = result.value

            if siid == DEHUMIDIFIER_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == FAULT_PIID then
                    emit_fault(device, value)
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(controlsMode.mode({value = mode}))
                    end
                elseif piid == TARGET_HUMIDITY_PIID then
                    device:emit_event(controlsTargetHumidity.targetHumidity({value = value, unit = "%"}))
                end
            elseif siid == ENVIRONMENT_SIID then
                if piid == HUMIDITY_PIID then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                end
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(controlsAlarm.alarm({value = bool_to_st(value)}))
            elseif siid == INDICATOR_SIID then
                if piid == INDICATOR_ON_PIID then
                    indicator_on = value
                elseif piid == INDICATOR_MODE_PIID then
                    indicator_mode = value
                end
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(controlsChildLock.childLock({value = bool_to_st(value)}))
            elseif siid == DM_SERVICE_SIID and piid == DRY_AFTER_OFF_PIID then
                device:emit_event(controlsDryAfterOff.dryAfterOff({value = bool_to_st(value)}))
            end
        end
    end

    if indicator_on == false or indicator_mode == 0 then
        device:emit_event(controlsIndicatorLight.indicatorLight({value = "off"}))
    elseif indicator_mode ~= nil then
        local indicator = INDICATOR_MODE_TO_ST[indicator_mode]
        if indicator then
            device:emit_event(controlsIndicatorLight.indicatorLight({value = indicator}))
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

    local ok = pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, POWER_PIID, false)
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

    pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, POWER_PIID, true)
    local ok = pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(controlsMode.mode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local humidity = math.max(30, math.min(70, command.args.humidity))
    local ok = pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, TARGET_HUMIDITY_PIID, humidity)
    if ok then
        device:emit_event(controlsTargetHumidity.targetHumidity({value = humidity, unit = "%"}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator = command.args.indicatorLight
    if indicator == "off" then
        local ok = pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_ON_PIID, false)
        if ok then
            device:emit_event(controlsIndicatorLight.indicatorLight({value = "off"}))
        end
        return
    end

    local value = ST_TO_INDICATOR_MODE[indicator]
    if value == nil then return end

    pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_ON_PIID, true)
    local ok = pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_MODE_PIID, value)
    if ok then
        device:emit_event(controlsIndicatorLight.indicatorLight({value = indicator}))
    end
end

local function set_alarm_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local alarm = command.args.alarm
    local ok = pcall(miot.set, device, ip, token, ALARM_SIID, ALARM_PIID, alarm == "on")
    if ok then
        device:emit_event(controlsAlarm.alarm({value = alarm}))
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

local function set_dry_after_off_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local dry_after_off = command.args.dryAfterOff
    local ok = pcall(miot.set, device, ip, token, DM_SERVICE_SIID, DRY_AFTER_OFF_PIID, dry_after_off == "on")
    if ok then
        device:emit_event(controlsDryAfterOff.dryAfterOff({value = dry_after_off}))
    end
end

local function reset_filter_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.action, device, ip, token, DM_SERVICE_SIID, RESET_FILTER_AIID, {})
    if ok then
        device:emit_event(statusFilterStatus.filterStatus({value = "normal"}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(controlsMode.ID, "main") then
        device:try_update_metadata({profile = "xiaomi-dehumidifier-13l"})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(controlsMode.mode({value = "smart"}))
    device:emit_event(controlsTargetHumidity.targetHumidity({value = 50, unit = "%"}))
    device:emit_event(controlsIndicatorLight.indicatorLight({value = "full"}))
    device:emit_event(controlsAlarm.alarm({value = "off"}))
    device:emit_event(controlsChildLock.childLock({value = "off"}))
    device:emit_event(controlsDryAfterOff.dryAfterOff({value = "off"}))
    device:emit_event(statusTankStatus.tankStatus({value = "normal"}))
    device:emit_event(statusFilterStatus.filterStatus({value = "normal"}))
    device:emit_event(statusFault.fault({value = "noFaults"}))
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

local driver = Driver("miot-xiaomi-dehumidifier-13l", {
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
        [controlsMode.ID] = {
            [controlsMode.commands.setMode.NAME] = set_mode_handler
        },
        [controlsTargetHumidity.ID] = {
            [controlsTargetHumidity.commands.setTargetHumidity.NAME] = set_target_humidity_handler
        },
        [controlsIndicatorLight.ID] = {
            [controlsIndicatorLight.commands.setIndicatorLight.NAME] = set_indicator_light_handler
        },
        [controlsAlarm.ID] = {
            [controlsAlarm.commands.setAlarm.NAME] = set_alarm_handler
        },
        [controlsChildLock.ID] = {
            [controlsChildLock.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [controlsDryAfterOff.ID] = {
            [controlsDryAfterOff.commands.setDryAfterOff.NAME] = set_dry_after_off_handler
        },
        [controlsResetFilter.ID] = {
            [controlsResetFilter.commands.resetFilter.NAME] = reset_filter_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
