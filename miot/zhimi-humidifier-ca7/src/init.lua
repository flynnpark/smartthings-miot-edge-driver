-- Zhimi Humidifier CA7 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local modeControl = capabilities["concertmirror08464.zhimiHumCa7Mode"]
local targetHumidityControl = capabilities["concertmirror08464.zhimiHumCa7TargetHumidity"]
local operatingStatus = capabilities["concertmirror08464.zhimiHumCa7Status"]
local waterLevelStatus = capabilities["concertmirror08464.zhimiHumCa7WaterLevel"]
local screenBrightnessControl = capabilities["concertmirror08464.zhimiHumCa7ScreenBrightness"]
local alarmControl = capabilities["concertmirror08464.zhimiHumCa7Alarm"]
local childLockControl = capabilities["concertmirror08464.zhimiHumCa7ChildLock"]
local airDryControl = capabilities["concertmirror08464.zhimiHumCa7AirDry"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "zhimi-humidifier-ca7"

-- MIoT model: zhimi.humidifier.ca7
-- specModel: zhimi-ca7
-- URN: urn:miot-spec-v2:device:humidifier:0000A00E:zhimi-ca7:1:0000D061
--
-- Humidifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, 0..15, not exposed
--   piid=3 mode, uint8, RW enum: 2=sleep, 3=auto, 4=favorite
--   piid=5 target-humidity, uint8, RW range 30..60 step 1, %
--   piid=6 water-level, uint8, R range 0..2: 0=empty, 1=low, 2=normal
--   piid=9 automatic-air-drying, bool, RW
--   piid=11 status, uint8, R enum: 1=close, 2=work, 3=dry, 4=clean
--   aiid=1 toggle, action, not exposed
-- environment service (siid=3)
--   piid=1 relative-humidity, uint8, R, 0..100 %
--   piid=2 temperature, float, R, celsius
-- screen service (siid=6)
--   piid=2 screen-brightness, uint8, RW enum: 0=close, 1=dim, 2=normal
-- alarm service (siid=7)
--   piid=1 alarm, bool, RW
-- child-lock service (siid=8)
--   piid=1 child-lock, bool, RW
-- other service (siid=10): country code, motor and debug values, not exposed

local HUMIDIFIER_SIID = 2
local POWER_PIID = 1
local MODE_PIID = 3
local TARGET_HUMIDITY_PIID = 5
local WATER_LEVEL_PIID = 6
local AIR_DRY_PIID = 9
local STATUS_PIID = 11

local ENVIRONMENT_SIID = 3
local HUMIDITY_PIID = 1
local TEMPERATURE_PIID = 2

local SCREEN_SIID = 6
local SCREEN_BRIGHTNESS_PIID = 2

local ALARM_SIID = 7
local ALARM_PIID = 1

local CHILD_LOCK_SIID = 8
local CHILD_LOCK_PIID = 1

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [2] = "sleep",
    [3] = "auto",
    [4] = "favorite"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    sleep = 2,
    auto = 3,
    favorite = 4
}

local WATER_LEVEL_TO_ST = {
    [0] = "empty",
    [1] = "low",
    [2] = "normal"
}

local STATUS_TO_ST = {
    [1] = "close",
    [2] = "work",
    [3] = "dry",
    [4] = "clean"
}

local SCREEN_BRIGHTNESS_TO_ST = {
    [0] = "close",
    [1] = "dim",
    [2] = "normal"
}

local ST_TO_SCREEN_BRIGHTNESS = {
    close = 0,
    dim = 1,
    normal = 2
}

local TARGET_HUMIDITY_MIN = 30
local TARGET_HUMIDITY_MAX = 60

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
        {siid = HUMIDIFIER_SIID, piid = POWER_PIID},
        {siid = HUMIDIFIER_SIID, piid = MODE_PIID},
        {siid = HUMIDIFIER_SIID, piid = TARGET_HUMIDITY_PIID},
        {siid = HUMIDIFIER_SIID, piid = WATER_LEVEL_PIID},
        {siid = HUMIDIFIER_SIID, piid = AIR_DRY_PIID},
        {siid = HUMIDIFIER_SIID, piid = STATUS_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = SCREEN_SIID, piid = SCREEN_BRIGHTNESS_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID}
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
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(modeControl.mode({value = mode}))
                    end
                elseif piid == TARGET_HUMIDITY_PIID then
                    device:emit_event(targetHumidityControl.targetHumidity({value = value, unit = "%"}))
                elseif piid == WATER_LEVEL_PIID then
                    local level = WATER_LEVEL_TO_ST[value]
                    if level then
                        device:emit_event(waterLevelStatus.waterLevel({value = level}))
                    end
                elseif piid == AIR_DRY_PIID then
                    device:emit_event(airDryControl.airDry({value = bool_to_st(value)}))
                elseif piid == STATUS_PIID then
                    local status = STATUS_TO_ST[value]
                    if status then
                        device:emit_event(operatingStatus.operatingStatus({value = status}))
                    end
                end
            elseif siid == ENVIRONMENT_SIID then
                if piid == HUMIDITY_PIID then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                end
            elseif siid == SCREEN_SIID and piid == SCREEN_BRIGHTNESS_PIID then
                local brightness = SCREEN_BRIGHTNESS_TO_ST[value]
                if brightness then
                    device:emit_event(screenBrightnessControl.screenBrightness({value = brightness}))
                end
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(alarmControl.alarm({value = bool_to_st(value)}))
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(childLockControl.childLock({value = bool_to_st(value)}))
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

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local target = tonumber(command.args.humidity)
    if not target then return end
    if target < TARGET_HUMIDITY_MIN or target > TARGET_HUMIDITY_MAX then return end

    local value = math.floor(target)
    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, TARGET_HUMIDITY_PIID, value)
    if ok then
        device:emit_event(targetHumidityControl.targetHumidity({value = value, unit = "%"}))
    end
end

local function set_screen_brightness_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local brightness = command.args.screenBrightness
    local value = ST_TO_SCREEN_BRIGHTNESS[brightness]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, SCREEN_SIID, SCREEN_BRIGHTNESS_PIID, value)
    if ok then
        device:emit_event(screenBrightnessControl.screenBrightness({value = brightness}))
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

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    local ok = pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, child_lock == "on")
    if ok then
        device:emit_event(childLockControl.childLock({value = child_lock}))
    end
end

local function set_air_dry_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local air_dry = command.args.airDry
    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, AIR_DRY_PIID, air_dry == "on")
    if ok then
        device:emit_event(airDryControl.airDry({value = air_dry}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(airDryControl.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(modeControl.mode({value = "auto"}))
    device:emit_event(targetHumidityControl.targetHumidity({value = 50, unit = "%"}))
    device:emit_event(operatingStatus.operatingStatus({value = "close"}))
    device:emit_event(waterLevelStatus.waterLevel({value = "normal"}))
    device:emit_event(screenBrightnessControl.screenBrightness({value = "normal"}))
    device:emit_event(alarmControl.alarm({value = "off"}))
    device:emit_event(childLockControl.childLock({value = "off"}))
    device:emit_event(airDryControl.airDry({value = "off"}))
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

local driver = Driver("miot-zhimi-humidifier-ca7", {
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
        [screenBrightnessControl.ID] = {
            [screenBrightnessControl.commands.setScreenBrightness.NAME] = set_screen_brightness_handler
        },
        [alarmControl.ID] = {
            [alarmControl.commands.setAlarm.NAME] = set_alarm_handler
        },
        [childLockControl.ID] = {
            [childLockControl.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [airDryControl.ID] = {
            [airDryControl.commands.setAirDry.NAME] = set_air_dry_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
