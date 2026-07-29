-- Hanyi Air Purifier KJ550 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local modeCap = capabilities["concertmirror08464.hanyiAirKj550Mode"]
local fanSpeedCap = capabilities["concertmirror08464.hanyiAirKj550FanSpeed"]
local filterTimeCap = capabilities["concertmirror08464.hanyiAirKj550FilterTime"]
local anionCap = capabilities["concertmirror08464.hanyiAirKj550Anion"]
local indicatorCap = capabilities["concertmirror08464.hanyiAirKj550Indicator"]
local childLockCap = capabilities["concertmirror08464.hanyiAirKj550ChildLock"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "hanyi-air-purifier-kj550"

-- MIoT model: hanyi.airpurifier.kj550
-- specModel: hanyi-kj550
-- URN: urn:miot-spec-v2:device:air-purifier:0000A007:hanyi-kj550:1
--
-- Air Purifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, single no-fault value, not exposed
--   piid=4 mode, uint8, RW enum: 0=auto, 1=sleep, 2=manual
--   piid=5 fan-level, uint8, RW range 0..100 (stepless, not an enum)
--   piid=6 anion, bool, RW
-- Environment service (siid=3)
--   piid=4 pm2.5-density, uint16, R
--   piid=5 indoor-temperature, int16, R, celsius
--   piid=6 relative-humidity, uint8, R, percent
-- Filter service (siid=4)
--   piid=2 filter-left-time, uint16, R, hours
-- Indicator Light service (siid=5)
--   piid=1 on, uint8, RW enum: 0=close, 1=bright, 2=dark
-- Custom service (siid=6)
--   piid=1 childlock, bool, RW
--   piid=2 reset, piid=3/4 timer setters, and piid=5/6 remaining countdowns
--     are maintenance and schedule fields, not exposed

local PURIFIER_SIID = 2
local POWER_PIID = 1
local MODE_PIID = 4
local FAN_LEVEL_PIID = 5
local ANION_PIID = 6

local ENVIRONMENT_SIID = 3
local PM25_PIID = 4
local TEMPERATURE_PIID = 5
local HUMIDITY_PIID = 6

local FILTER_SIID = 4
local FILTER_LEFT_TIME_PIID = 2

local INDICATOR_SIID = 5
local INDICATOR_PIID = 1

local CUSTOM_SIID = 6
local CHILD_LOCK_PIID = 1

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [0] = "auto",
    [1] = "sleep",
    [2] = "manual"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    auto = 0,
    sleep = 1,
    manual = 2
}

local INDICATOR_TO_ST = {
    [0] = "off",
    [1] = "bright",
    [2] = "dark"
}

local ST_TO_INDICATOR = {
    off = 0,
    bright = 1,
    dark = 2
}

local FAN_SPEED_MAX = 100

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(modeCap.ID, "main") then
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
        {siid = PURIFIER_SIID, piid = POWER_PIID},
        {siid = PURIFIER_SIID, piid = MODE_PIID},
        {siid = PURIFIER_SIID, piid = FAN_LEVEL_PIID},
        {siid = PURIFIER_SIID, piid = ANION_PIID},
        {siid = ENVIRONMENT_SIID, piid = PM25_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = FILTER_SIID, piid = FILTER_LEFT_TIME_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_PIID},
        {siid = CUSTOM_SIID, piid = CHILD_LOCK_PIID}
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

            if siid == PURIFIER_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(bool_to_st(value)))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(modeCap.airPurifierMode({value = mode}))
                    end
                elseif piid == FAN_LEVEL_PIID then
                    device:emit_event(fanSpeedCap.fanSpeed({value = value, unit = "%"}))
                elseif piid == ANION_PIID then
                    device:emit_event(anionCap.anion({value = bool_to_st(value)}))
                end
            elseif siid == ENVIRONMENT_SIID then
                if piid == PM25_PIID then
                    device:emit_event(capabilities.dustSensor.fineDustLevel(math.floor(value)))
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == HUMIDITY_PIID then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                end
            elseif siid == FILTER_SIID and piid == FILTER_LEFT_TIME_PIID then
                device:emit_event(filterTimeCap.filterLeftTime({value = value, unit = "h"}))
            elseif siid == INDICATOR_SIID and piid == INDICATOR_PIID then
                local brightness = INDICATOR_TO_ST[value]
                if brightness then
                    device:emit_event(indicatorCap.indicatorBrightness({value = brightness}))
                end
            elseif siid == CUSTOM_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(childLockCap.childLock({value = bool_to_st(value)}))
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

    local ok = pcall(miot.set, device, ip, token, PURIFIER_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, PURIFIER_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.airPurifierMode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, PURIFIER_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(modeCap.airPurifierMode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_fan_speed_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.fanSpeed)
    if not requested then return end

    local value = math.max(0, math.min(FAN_SPEED_MAX, math.floor(requested + 0.5)))
    local ok = pcall(miot.set, device, ip, token, PURIFIER_SIID, FAN_LEVEL_PIID, value)
    if ok then
        device:emit_event(fanSpeedCap.fanSpeed({value = value, unit = "%"}))
    end
end

local function set_indicator_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local brightness = command.args.indicatorBrightness
    local value = ST_TO_INDICATOR[brightness]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_PIID, value)
    if ok then
        device:emit_event(indicatorCap.indicatorBrightness({value = brightness}))
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

local set_anion_handler = make_bool_handler(PURIFIER_SIID, ANION_PIID, anionCap, "anion", "anion")
local set_child_lock_handler = make_bool_handler(CUSTOM_SIID, CHILD_LOCK_PIID, childLockCap, "childLock", "childLock")

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:online()
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(modeCap.airPurifierMode({value = "auto"}))
    device:emit_event(fanSpeedCap.fanSpeed({value = 0, unit = "%"}))
    device:emit_event(capabilities.dustSensor.fineDustLevel(0))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(filterTimeCap.filterLeftTime({value = 0, unit = "h"}))
    device:emit_event(anionCap.anion({value = "off"}))
    device:emit_event(indicatorCap.indicatorBrightness({value = "bright"}))
    device:emit_event(childLockCap.childLock({value = "off"}))
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

local driver = Driver("miot-hanyi-air-purifier-kj550", {
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
        [modeCap.ID] = {
            [modeCap.commands.setAirPurifierMode.NAME] = set_mode_handler
        },
        [fanSpeedCap.ID] = {
            [fanSpeedCap.commands.setFanSpeed.NAME] = set_fan_speed_handler
        },
        [anionCap.ID] = {
            [anionCap.commands.setAnion.NAME] = set_anion_handler
        },
        [indicatorCap.ID] = {
            [indicatorCap.commands.setIndicatorBrightness.NAME] = set_indicator_handler
        },
        [childLockCap.ID] = {
            [childLockCap.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
