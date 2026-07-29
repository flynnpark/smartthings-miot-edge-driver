-- NWT Dehumidifier 16L Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local modeControl = capabilities["concertmirror08464.nwtDerh16lMode"]
local targetHumidityControl = capabilities["concertmirror08464.nwtDerh16lTargetHumidity"]
local indicatorLightControl = capabilities["concertmirror08464.nwtDerh16lIndicatorLight"]
local alarmControl = capabilities["concertmirror08464.nwtDerh16lAlarm"]
local tankStatus = capabilities["concertmirror08464.nwtDerh16lTankStatus"]
local defrostStatus = capabilities["concertmirror08464.nwtDerh16lDefrost"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "nwt-dehumidifier-16l"

-- MIoT model: nwt.fan.16l
-- specModel: nwt-16l
-- URN: urn:miot-spec-v2:device:dehumidifier:0000A02D:nwt-16l:2
--
-- Dehumidifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R: 0=noFaults, 1=E1, 2=E2, 3=E4, not exposed
--   piid=3 target-humidity, uint8, RW range 30..90 step 5, %
--   piid=4 mode, uint8, RW enum: 1=dry, 2=clothesDrying
-- Environment service (siid=3)
--   piid=1 relative-humidity, uint8, R, 0..100 %
-- Alarm service (siid=4)
--   piid=1 alarm, bool, RW
-- Indicator Light service (siid=5)
--   piid=1 on, bool, RW
-- syn service (siid=6)
--   piid=1 full-water, bool, R: true=full, false=normal
--   piid=2 defrosting, bool, R: true=defrosting, false=idle
--   piid=3 filter-cleaning, bool, R, not exposed

local DEHUMIDIFIER_SIID = 2
local POWER_PIID = 1
local TARGET_HUMIDITY_PIID = 3
local MODE_PIID = 4

local ENVIRONMENT_SIID = 3
local HUMIDITY_PIID = 1

local ALARM_SIID = 4
local ALARM_PIID = 1

local INDICATOR_SIID = 5
local INDICATOR_ON_PIID = 1

local SYN_SIID = 6
local FULL_WATER_PIID = 1
local DEFROSTING_PIID = 2

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [1] = "dry",
    [2] = "clothesDrying"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    dry = 1,
    clothesDrying = 2
}

local TARGET_HUMIDITY_MIN = 30
local TARGET_HUMIDITY_MAX = 90
local TARGET_HUMIDITY_STEP = 5

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

-- Target humidity uses a 30..90 step 5 range on the device and an "h<value>"
-- string enum in SmartThings, so both directions convert here.
local function humidity_to_st(value)
    if type(value) ~= "number" then
        return nil
    end
    if value < TARGET_HUMIDITY_MIN or value > TARGET_HUMIDITY_MAX then
        return nil
    end
    if value % TARGET_HUMIDITY_STEP ~= 0 then
        return nil
    end
    return "h" .. tostring(value)
end

local function st_to_humidity(value)
    if type(value) ~= "string" then
        return nil
    end
    local number = tonumber(value:match("^h(%d+)$"))
    if not number then
        return nil
    end
    if number < TARGET_HUMIDITY_MIN or number > TARGET_HUMIDITY_MAX then
        return nil
    end
    return number
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = DEHUMIDIFIER_SIID, piid = POWER_PIID},
        {siid = DEHUMIDIFIER_SIID, piid = TARGET_HUMIDITY_PIID},
        {siid = DEHUMIDIFIER_SIID, piid = MODE_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_ON_PIID},
        {siid = SYN_SIID, piid = FULL_WATER_PIID},
        {siid = SYN_SIID, piid = DEFROSTING_PIID}
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
                elseif piid == TARGET_HUMIDITY_PIID then
                    local target = humidity_to_st(value)
                    if target then
                        device:emit_event(targetHumidityControl.targetHumidity({value = target}))
                    end
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(modeControl.mode({value = mode}))
                    end
                end
            elseif siid == ENVIRONMENT_SIID and piid == HUMIDITY_PIID then
                device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(alarmControl.alarm({value = bool_to_st(value)}))
            elseif siid == INDICATOR_SIID and piid == INDICATOR_ON_PIID then
                device:emit_event(indicatorLightControl.indicatorLight({value = bool_to_st(value)}))
            elseif siid == SYN_SIID then
                if piid == FULL_WATER_PIID then
                    device:emit_event(tankStatus.tankStatus({value = value and "full" or "normal"}))
                elseif piid == DEFROSTING_PIID then
                    device:emit_event(defrostStatus.defrostStatus({value = value and "defrosting" or "idle"}))
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
        device:emit_event(modeControl.mode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local target = command.args.targetHumidity
    local value = st_to_humidity(target)
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, TARGET_HUMIDITY_PIID, value)
    if ok then
        device:emit_event(targetHumidityControl.targetHumidity({value = target}))
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
    if not device:supports_capability_by_id(modeControl.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(modeControl.mode({value = "dry"}))
    device:emit_event(targetHumidityControl.targetHumidity({value = "h50"}))
    device:emit_event(indicatorLightControl.indicatorLight({value = "on"}))
    device:emit_event(alarmControl.alarm({value = "off"}))
    device:emit_event(tankStatus.tankStatus({value = "normal"}))
    device:emit_event(defrostStatus.defrostStatus({value = "idle"}))
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

local driver = Driver("miot-nwt-dehumidifier-16l", {
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
