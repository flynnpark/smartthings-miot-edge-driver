-- Xiaomi Hood JYJSS2 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local fanLevelCap = capabilities["concertmirror08464.xiaomiHoodJyj2FanLevel"]
local lightCap = capabilities["concertmirror08464.xiaomiHoodJyj2Light"]
local offDelayCap = capabilities["concertmirror08464.xiaomiHoodJyj2OffDelay"]
local delayTimeCap = capabilities["concertmirror08464.xiaomiHoodJyj2DelayTime"]
local countdownCap = capabilities["concertmirror08464.xiaomiHoodJyj2Countdown"]
local cleanRemindCap = capabilities["concertmirror08464.xiaomiHoodJyj2CleanRemind"]
local cleanTimeCap = capabilities["concertmirror08464.xiaomiHoodJyj2CleanTime"]
local gesturesCap = capabilities["concertmirror08464.xiaomiHoodJyj2Gestures"]
local autoVentCap = capabilities["concertmirror08464.xiaomiHoodJyj2AutoVent"]
local stoveLinkCap = capabilities["concertmirror08464.xiaomiHoodJyj2StoveLink"]
local batteryCap = capabilities["concertmirror08464.xiaomiHoodJyj2Battery"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "xiaomi-hood-jyjss2"

-- MIoT model: xiaomi.hood.jyjss2
-- specModel: xiaomi-jyjss2
-- URN: urn:miot-spec-v2:device:hood:0000A01B:xiaomi-jyjss2:3
--
-- Hood service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint32, R, raw code, not exposed
--   piid=5 off-delay, bool, RW
--   piid=6 off-delay-time, uint8, RW range 0..7 minutes
--   piid=7 countdown-time, uint32, RW range 0..420 minutes
--   piid=8 stove-link-status, uint8, R enum: 0=unbound, 1=unlinked, 2=linked
--   piid=11 clean-remind-on, bool, RW
--   piid=12 clean-remind-time, uint8, RW range 20..50 hours, step 10
--   piid=18 gestures, bool, RW
--   piid=20 auto-ventilation-on, bool, RW
--   piid=9/10 power-on-with-light and power-off-with-light are light-linkage
--     preferences, piid=19 working-remind-time is a reminder schedule, and
--     piid=21..23 are PM trigger thresholds for auto ventilation
-- Fan Control service (siid=3)
--   piid=1 fan-level, uint8, RW enum: 1=low, 2=high, 3=turbo
-- Light service (siid=6)
--   piid=1 on, bool, RW
-- Battery service (siid=11)
--   piid=1 battery-level, uint8, R enum: 0=low, 1=normal (remote battery)
-- Environment service (siid=12)
--   piid=1 pm2.5-density, float, R
--   piid=2..4 report which input last triggered the hood, so they are usage
--     history rather than device state
-- Kitchen Stove services (siid=4, siid=5) and the dry-wash service expose
--   burner telemetry and a cleaning program that need the paired stove

local HOOD_SIID = 2
local POWER_PIID = 1
local OFF_DELAY_PIID = 5
local OFF_DELAY_TIME_PIID = 6
local COUNTDOWN_PIID = 7
local STOVE_LINK_PIID = 8
local CLEAN_REMIND_PIID = 11
local CLEAN_REMIND_TIME_PIID = 12
local GESTURES_PIID = 18
local AUTO_VENT_PIID = 20

local FAN_SIID = 3
local FAN_LEVEL_PIID = 1

local LIGHT_SIID = 6
local LIGHT_ON_PIID = 1

local BATTERY_SIID = 11
local BATTERY_LEVEL_PIID = 1

local ENVIRONMENT_SIID = 12
local PM25_PIID = 1

-- MIoT -> SmartThings
local FAN_LEVEL_TO_ST = {
    [1] = "low",
    [2] = "high",
    [3] = "turbo"
}

-- SmartThings -> MIoT
local ST_TO_FAN_LEVEL = {
    low = 1,
    high = 2,
    turbo = 3
}

local STOVE_LINK_TO_ST = {
    [0] = "unbound",
    [1] = "unlinked",
    [2] = "linked"
}

local BATTERY_TO_ST = {
    [0] = "low",
    [1] = "normal"
}

local OFF_DELAY_TIME_MAX = 7
local COUNTDOWN_MAX = 420
local CLEAN_TIME_MIN = 20
local CLEAN_TIME_MAX = 50

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(fanLevelCap.ID, "main") then
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
        {siid = HOOD_SIID, piid = POWER_PIID},
        {siid = HOOD_SIID, piid = OFF_DELAY_PIID},
        {siid = HOOD_SIID, piid = OFF_DELAY_TIME_PIID},
        {siid = HOOD_SIID, piid = COUNTDOWN_PIID},
        {siid = HOOD_SIID, piid = STOVE_LINK_PIID},
        {siid = HOOD_SIID, piid = CLEAN_REMIND_PIID},
        {siid = HOOD_SIID, piid = CLEAN_REMIND_TIME_PIID},
        {siid = HOOD_SIID, piid = GESTURES_PIID},
        {siid = HOOD_SIID, piid = AUTO_VENT_PIID},
        {siid = FAN_SIID, piid = FAN_LEVEL_PIID},
        {siid = LIGHT_SIID, piid = LIGHT_ON_PIID},
        {siid = BATTERY_SIID, piid = BATTERY_LEVEL_PIID},
        {siid = ENVIRONMENT_SIID, piid = PM25_PIID}
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

            if siid == HOOD_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(bool_to_st(value)))
                elseif piid == OFF_DELAY_PIID then
                    device:emit_event(offDelayCap.offDelay({value = bool_to_st(value)}))
                elseif piid == OFF_DELAY_TIME_PIID then
                    device:emit_event(delayTimeCap.offDelayTime({value = value, unit = "min"}))
                elseif piid == COUNTDOWN_PIID then
                    device:emit_event(countdownCap.countdownTime({value = value, unit = "min"}))
                elseif piid == STOVE_LINK_PIID then
                    local link = STOVE_LINK_TO_ST[value]
                    if link then
                        device:emit_event(stoveLinkCap.stoveLink({value = link}))
                    end
                elseif piid == CLEAN_REMIND_PIID then
                    device:emit_event(cleanRemindCap.cleanRemind({value = bool_to_st(value)}))
                elseif piid == CLEAN_REMIND_TIME_PIID then
                    device:emit_event(cleanTimeCap.cleanRemindTime({value = value, unit = "h"}))
                elseif piid == GESTURES_PIID then
                    device:emit_event(gesturesCap.gestures({value = bool_to_st(value)}))
                elseif piid == AUTO_VENT_PIID then
                    device:emit_event(autoVentCap.autoVentilation({value = bool_to_st(value)}))
                end
            elseif siid == FAN_SIID and piid == FAN_LEVEL_PIID then
                local level = FAN_LEVEL_TO_ST[value]
                if level then
                    device:emit_event(fanLevelCap.fanLevel({value = level}))
                end
            elseif siid == LIGHT_SIID and piid == LIGHT_ON_PIID then
                device:emit_event(lightCap.hoodLight({value = bool_to_st(value)}))
            elseif siid == BATTERY_SIID and piid == BATTERY_LEVEL_PIID then
                local battery = BATTERY_TO_ST[value]
                if battery then
                    device:emit_event(batteryCap.batteryState({value = battery}))
                end
            elseif siid == ENVIRONMENT_SIID and piid == PM25_PIID then
                device:emit_event(capabilities.dustSensor.fineDustLevel(math.floor(value)))
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

    local ok = pcall(miot.set, device, ip, token, HOOD_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, HOOD_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_fan_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = command.args.fanLevel
    local value = ST_TO_FAN_LEVEL[level]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, FAN_LEVEL_PIID, value)
    if ok then
        device:emit_event(fanLevelCap.fanLevel({value = level}))
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

local set_light_handler = make_bool_handler(LIGHT_SIID, LIGHT_ON_PIID, lightCap, "hoodLight", "hoodLight")
local set_off_delay_handler = make_bool_handler(HOOD_SIID, OFF_DELAY_PIID, offDelayCap, "offDelay", "offDelay")
local set_clean_remind_handler = make_bool_handler(HOOD_SIID, CLEAN_REMIND_PIID, cleanRemindCap, "cleanRemind", "cleanRemind")
local set_gestures_handler = make_bool_handler(HOOD_SIID, GESTURES_PIID, gesturesCap, "gestures", "gestures")
local set_auto_vent_handler = make_bool_handler(HOOD_SIID, AUTO_VENT_PIID, autoVentCap, "autoVentilation", "autoVentilation")

local function make_number_handler(siid, piid, capability, attribute, argument, minimum, maximum, unit, step)
    return function(_, device, command)
        local ip, token = get_device_config(device)
        if not ip then return end

        local requested = tonumber(command.args[argument])
        if not requested then return end

        local value = math.floor(requested + 0.5)
        if step and step > 1 then
            value = minimum + math.floor((value - minimum) / step + 0.5) * step
        end
        value = math.max(minimum, math.min(maximum, value))

        local ok = pcall(miot.set, device, ip, token, siid, piid, value)
        if ok then
            device:emit_event(capability[attribute]({value = value, unit = unit}))
        end
    end
end

local set_delay_time_handler = make_number_handler(HOOD_SIID, OFF_DELAY_TIME_PIID, delayTimeCap, "offDelayTime", "offDelayTime", 0, OFF_DELAY_TIME_MAX, "min")
local set_countdown_handler = make_number_handler(HOOD_SIID, COUNTDOWN_PIID, countdownCap, "countdownTime", "countdownTime", 0, COUNTDOWN_MAX, "min")
-- The clean reminder interval accepts 10 hour steps, so snap the request.
local set_clean_time_handler = make_number_handler(HOOD_SIID, CLEAN_REMIND_TIME_PIID, cleanTimeCap, "cleanRemindTime", "cleanRemindTime", CLEAN_TIME_MIN, CLEAN_TIME_MAX, "h", 10)

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:online()
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(fanLevelCap.fanLevel({value = "low"}))
    device:emit_event(lightCap.hoodLight({value = "off"}))
    device:emit_event(capabilities.dustSensor.fineDustLevel(0))
    device:emit_event(offDelayCap.offDelay({value = "off"}))
    device:emit_event(delayTimeCap.offDelayTime({value = 0, unit = "min"}))
    device:emit_event(countdownCap.countdownTime({value = 0, unit = "min"}))
    device:emit_event(cleanRemindCap.cleanRemind({value = "off"}))
    device:emit_event(cleanTimeCap.cleanRemindTime({value = 30, unit = "h"}))
    device:emit_event(gesturesCap.gestures({value = "off"}))
    device:emit_event(autoVentCap.autoVentilation({value = "off"}))
    device:emit_event(stoveLinkCap.stoveLink({value = "unbound"}))
    device:emit_event(batteryCap.batteryState({value = "normal"}))
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

local driver = Driver("miot-xiaomi-hood-jyjss2", {
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
        [fanLevelCap.ID] = {
            [fanLevelCap.commands.setFanLevel.NAME] = set_fan_level_handler
        },
        [lightCap.ID] = {
            [lightCap.commands.setHoodLight.NAME] = set_light_handler
        },
        [offDelayCap.ID] = {
            [offDelayCap.commands.setOffDelay.NAME] = set_off_delay_handler
        },
        [delayTimeCap.ID] = {
            [delayTimeCap.commands.setOffDelayTime.NAME] = set_delay_time_handler
        },
        [countdownCap.ID] = {
            [countdownCap.commands.setCountdownTime.NAME] = set_countdown_handler
        },
        [cleanRemindCap.ID] = {
            [cleanRemindCap.commands.setCleanRemind.NAME] = set_clean_remind_handler
        },
        [cleanTimeCap.ID] = {
            [cleanTimeCap.commands.setCleanRemindTime.NAME] = set_clean_time_handler
        },
        [gesturesCap.ID] = {
            [gesturesCap.commands.setGestures.NAME] = set_gestures_handler
        },
        [autoVentCap.ID] = {
            [autoVentCap.commands.setAutoVentilation.NAME] = set_auto_vent_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
