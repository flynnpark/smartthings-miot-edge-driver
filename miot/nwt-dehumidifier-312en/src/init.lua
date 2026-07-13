-- NWT Dehumidifier 312EN Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local controls = capabilities["concertmirror08464.nwtDerh312enControls"]
local status = capabilities["concertmirror08464.nwtDerh312enStatus"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60

-- MIoT model: nwt.derh.312en
-- specModel: nwt-312en
-- URN: urn:miot-spec-v2:device:dehumidifier:0000A02D:nwt-312en:2
--
-- Dehumidifier service (siid=2)
--   piid=1 power, bool, RW
--   piid=2 fault, uint8, R: 0=noFaults
--   piid=3 mode, uint8, RW: 1=smart, 2=clothesDrying
--   piid=5 target-humidity, uint8, RW enum: 30=continuous, 40/50/60/70 %
--   piid=7 fan-level, uint8, RW enum: 0=auto, 1=level1, not exposed
-- Environment service (siid=3)
--   piid=1 relative-humidity, uint8, R, 0..100 %
--   piid=7 temperature, float, R, celsius
-- Alarm service (siid=4)
--   piid=1 alarm, bool, RW
-- Indicator Light service (siid=5)
--   piid=1 on, bool, RW
-- Physical Control Locked service (siid=6)
--   piid=1 physical-controls-locked, bool, RW
-- Event service (siid=7)
--   piid=3 water-tank-status, bool, R: true=fullOrRemoved, false=normal

local DEHUMIDIFIER_SIID = 2
local POWER_PIID = 1
local MODE_PIID = 3
local TARGET_HUMIDITY_PIID = 5

local ENVIRONMENT_SIID = 3
local HUMIDITY_PIID = 1
local TEMPERATURE_PIID = 7

local ALARM_SIID = 4
local ALARM_PIID = 1

local INDICATOR_SIID = 5
local INDICATOR_ON_PIID = 1

local CHILD_LOCK_SIID = 6
local CHILD_LOCK_PIID = 1

local EVENT_SERVICE_SIID = 7
local WATER_TANK_STATUS_PIID = 3

local MODE_TO_ST = {
    [1] = "smart",
    [2] = "clothesDrying"
}

local ST_TO_MODE = {
    smart = 1,
    clothesDrying = 2
}

local TARGET_HUMIDITY_TO_ST = {
    [30] = "continuous",
    [40] = "h40",
    [50] = "h50",
    [60] = "h60",
    [70] = "h70"
}

local ST_TO_TARGET_HUMIDITY = {
    continuous = 30,
    h40 = 40,
    h50 = 50,
    h60 = 60,
    h70 = 70
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

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = DEHUMIDIFIER_SIID, piid = POWER_PIID},
        {siid = DEHUMIDIFIER_SIID, piid = MODE_PIID},
        {siid = DEHUMIDIFIER_SIID, piid = TARGET_HUMIDITY_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_ON_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = EVENT_SERVICE_SIID, piid = WATER_TANK_STATUS_PIID}
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

            if siid == DEHUMIDIFIER_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(controls.mode({value = mode}))
                    end
                elseif piid == TARGET_HUMIDITY_PIID then
                    local target = TARGET_HUMIDITY_TO_ST[value]
                    if target then
                        device:emit_event(controls.targetHumidity({value = target}))
                    end
                end
            elseif siid == ENVIRONMENT_SIID then
                if piid == HUMIDITY_PIID then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                end
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(controls.alarm({value = bool_to_st(value)}))
            elseif siid == INDICATOR_SIID and piid == INDICATOR_ON_PIID then
                device:emit_event(controls.indicatorLight({value = bool_to_st(value)}))
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(controls.childLock({value = bool_to_st(value)}))
            elseif siid == EVENT_SERVICE_SIID and piid == WATER_TANK_STATUS_PIID then
                device:emit_event(status.tankStatus({value = value and "fullOrRemoved" or "normal"}))
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
        device:emit_event(controls.mode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local target_humidity = command.args.targetHumidity
    local value = ST_TO_TARGET_HUMIDITY[target_humidity]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, TARGET_HUMIDITY_PIID, value)
    if ok then
        device:emit_event(controls.targetHumidity({value = target_humidity}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator = command.args.indicatorLight
    local ok = pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_ON_PIID, indicator == "on")
    if ok then
        device:emit_event(controls.indicatorLight({value = indicator}))
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

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    local ok = pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, child_lock == "on")
    if ok then
        device:emit_event(controls.childLock({value = child_lock}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(controls.ID, "main") then
        device:try_update_metadata({profile = "nwt-dehumidifier-312en"})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(controls.mode({value = "smart"}))
    device:emit_event(controls.targetHumidity({value = "h50"}))
    device:emit_event(controls.indicatorLight({value = "on"}))
    device:emit_event(controls.alarm({value = "off"}))
    device:emit_event(controls.childLock({value = "off"}))
    device:emit_event(status.tankStatus({value = "normal"}))
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

local driver = Driver("miot-nwt-dehumidifier-312en", {
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
            [controls.commands.setMode.NAME] = set_mode_handler,
            [controls.commands.setTargetHumidity.NAME] = set_target_humidity_handler,
            [controls.commands.setIndicatorLight.NAME] = set_indicator_light_handler,
            [controls.commands.setAlarm.NAME] = set_alarm_handler,
            [controls.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
