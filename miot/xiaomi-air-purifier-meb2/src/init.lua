-- Mijia Smart Air Purifier Elite Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local controls = capabilities["concertmirror08464.airPurifierEliteControls"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60

-- MIoT model: xiaomi.airp.meb2
-- specModel: xiaomi-meb2
-- URN: urn:miot-spec-v2:device:air-purifier:0000A007:xiaomi-meb2:1:0000D050
-- Source: Mijia Smart Air Purifier Elite Korea model docs, hass-xiaomi-miot MIoT LAN support, MIoT spec xiaomi-meb2 v1.
-- Air purifier service (siid=2)
local AIR_PURIFIER_SIID = 2
local POWER_PIID = 1             -- RW bool
local FAULT_PIID = 2             -- R enum, diagnostic only
local MODE_PIID = 4              -- RW enum: 0 auto, 1 sleep, 2 favorite, 3 manual
local FAN_LEVEL_PIID = 5         -- RW enum: 1 level1, 2 level2, 3 level3
local PLASMA_PIID = 6            -- RW bool
local UV_PIID = 7                -- RW bool

-- Environment service (siid=3)
local ENVIRONMENT_SIID = 3
local HUMIDITY_PIID = 1          -- R uint8, 0..100 %
local PM25_PIID = 4              -- R float, 0..1000 ug/m3
local TEMPERATURE_PIID = 7       -- R float, -30..100 C
local PM10_PIID = 8              -- R float, 0..100 ug/m3
local AIR_QUALITY_PIID = 9       -- R enum, not exposed

-- Filter service (siid=4)
local FILTER_SIID = 4
local FILTER_LIFE_PIID = 1       -- R uint8, 0..100 %
local FILTER_USED_TIME_PIID = 3  -- R uint16 hours, not exposed
local RESET_FILTER_AIID = 1      -- Action, not exposed

-- Alarm service (siid=6)
local BUZZER_SIID = 6
local BUZZER_PIID = 1            -- RW bool

-- Physical controls locked service (siid=8)
local CHILD_LOCK_SIID = 8
local CHILD_LOCK_PIID = 1        -- RW bool

-- Screen service (siid=13)
local SCREEN_SIID = 13
local DISPLAY_BRIGHTNESS_PIID = 2 -- RW enum: 0 off, 1 bright, 2 brightest

-- Favorite, display unit, custom diagnostics, filter-time, AQI heartbeat, and
-- RFID services are intentionally not exposed as core SmartThings controls.

local MODE_TO_ST = {
    [0] = "auto",
    [1] = "sleep",
    [2] = "favorite",
    [3] = "manual"
}

local ST_TO_MODE = {
    auto = 0,
    sleep = 1,
    favorite = 2,
    manual = 3
}

local FAN_LEVEL_TO_ST = {
    [1] = "level1",
    [2] = "level2",
    [3] = "level3"
}

local ST_TO_FAN_LEVEL = {
    level1 = 1,
    level2 = 2,
    level3 = 3
}

local DISPLAY_BRIGHTNESS_TO_ST = {
    [0] = "off",
    [1] = "bright",
    [2] = "brightest"
}

local ST_TO_DISPLAY_BRIGHTNESS = {
    off = 0,
    bright = 1,
    brightest = 2
}

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function bool_to_on_off(value)
    return value and "on" or "off"
end

local poll_device_status

local function schedule_refresh(device)
    device.thread:call_with_delay(1, function()
        pcall(poll_device_status, device)
    end)
end

poll_device_status = function(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = AIR_PURIFIER_SIID, piid = POWER_PIID},
        {siid = AIR_PURIFIER_SIID, piid = MODE_PIID},
        {siid = AIR_PURIFIER_SIID, piid = FAN_LEVEL_PIID},
        {siid = AIR_PURIFIER_SIID, piid = PLASMA_PIID},
        {siid = AIR_PURIFIER_SIID, piid = UV_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = ENVIRONMENT_SIID, piid = PM25_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = ENVIRONMENT_SIID, piid = PM10_PIID},
        {siid = FILTER_SIID, piid = FILTER_LIFE_PIID},
        {siid = BUZZER_SIID, piid = BUZZER_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = SCREEN_SIID, piid = DISPLAY_BRIGHTNESS_PIID}
    }

    local ok, response = pcall(miot.gets, device, ip, token, properties)
    if not ok then
        return
    end

    if not response or not response.result then
        return
    end

    for _, result in ipairs(response.result) do
        if result.code == 0 then
            local siid = result.siid
            local piid = result.piid
            local value = result.value

            if siid == AIR_PURIFIER_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(bool_to_on_off(value)))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(controls.airPurifierMode({value = mode}))
                    end
                elseif piid == FAN_LEVEL_PIID then
                    local level = FAN_LEVEL_TO_ST[value]
                    if level then
                        device:emit_event(controls.fanLevel({value = level}))
                    end
                elseif piid == PLASMA_PIID then
                    device:emit_event(controls.plasma({value = bool_to_on_off(value)}))
                elseif piid == UV_PIID then
                    device:emit_event(controls.uv({value = bool_to_on_off(value)}))
                end
            elseif siid == ENVIRONMENT_SIID then
                if piid == HUMIDITY_PIID then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                elseif piid == PM25_PIID then
                    device:emit_event(capabilities.dustSensor.fineDustLevel(math.floor(value)))
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == PM10_PIID then
                    device:emit_event(capabilities.dustSensor.dustLevel(math.floor(value)))
                end
            elseif siid == FILTER_SIID and piid == FILTER_LIFE_PIID then
                device:emit_event(capabilities.filterState.filterLifeRemaining({value = value, unit = "%"}))
            elseif siid == BUZZER_SIID and piid == BUZZER_PIID then
                device:emit_event(controls.buzzer({value = bool_to_on_off(value)}))
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(controls.childLock({value = bool_to_on_off(value)}))
            elseif siid == SCREEN_SIID and piid == DISPLAY_BRIGHTNESS_PIID then
                local brightness = DISPLAY_BRIGHTNESS_TO_ST[value]
                if brightness then
                    device:emit_event(controls.displayBrightness({value = brightness}))
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

local function handle_on(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.set, device, ip, token, AIR_PURIFIER_SIID, POWER_PIID, true)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        schedule_refresh(device)
    end
end

local function handle_off(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.set, device, ip, token, AIR_PURIFIER_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function handle_set_air_purifier_mode(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    pcall(miot.set, device, ip, token, AIR_PURIFIER_SIID, POWER_PIID, true)

    local ok = pcall(miot.set, device, ip, token, AIR_PURIFIER_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(controls.airPurifierMode({value = mode}))
        schedule_refresh(device)
    end
end

local function handle_set_fan_level(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local fan_level = command.args.fanLevel
    local value = ST_TO_FAN_LEVEL[fan_level]
    if value == nil then return end

    pcall(miot.set, device, ip, token, AIR_PURIFIER_SIID, POWER_PIID, true)
    pcall(miot.set, device, ip, token, AIR_PURIFIER_SIID, MODE_PIID, ST_TO_MODE.manual)

    local ok = pcall(miot.set, device, ip, token, AIR_PURIFIER_SIID, FAN_LEVEL_PIID, value)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(controls.airPurifierMode({value = "manual"}))
        device:emit_event(controls.fanLevel({value = fan_level}))
        schedule_refresh(device)
    end
end

local function handle_set_display_brightness(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local brightness = command.args.brightness
    local value = ST_TO_DISPLAY_BRIGHTNESS[brightness]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, SCREEN_SIID, DISPLAY_BRIGHTNESS_PIID, value)
    if ok then
        device:emit_event(controls.displayBrightness({value = brightness}))
    end
end

local function handle_set_plasma(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local plasma = command.args.plasma
    local value = plasma == "on"
    local ok = pcall(miot.set, device, ip, token, AIR_PURIFIER_SIID, PLASMA_PIID, value)
    if ok then
        device:emit_event(controls.plasma({value = plasma}))
    end
end

local function handle_set_uv(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local uv = command.args.uv
    local value = uv == "on"
    local ok = pcall(miot.set, device, ip, token, AIR_PURIFIER_SIID, UV_PIID, value)
    if ok then
        device:emit_event(controls.uv({value = uv}))
    end
end

local function handle_set_buzzer(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local buzzer = command.args.buzzer
    local value = buzzer == "on"
    local ok = pcall(miot.set, device, ip, token, BUZZER_SIID, BUZZER_PIID, value)
    if ok then
        device:emit_event(controls.buzzer({value = buzzer}))
    end
end

local function handle_set_child_lock(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    local value = child_lock == "on"
    local ok = pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, value)
    if ok then
        device:emit_event(controls.childLock({value = child_lock}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(controls.airPurifierMode({value = "auto"}))
    device:emit_event(controls.fanLevel({value = "level1"}))
    device:emit_event(controls.displayBrightness({value = "brightest"}))
    device:emit_event(controls.plasma({value = "off"}))
    device:emit_event(controls.uv({value = "off"}))
    device:emit_event(controls.buzzer({value = "off"}))
    device:emit_event(controls.childLock({value = "off"}))
    device:emit_event(capabilities.dustSensor.fineDustLevel(0))
    device:emit_event(capabilities.dustSensor.dustLevel(0))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(capabilities.filterState.filterState.normal())
    device:emit_event(capabilities.filterState.filterLifeRemaining({value = 100, unit = "%"}))
end

local function device_init(_, device)
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

local driver = Driver("miot-xiaomi-air-purifier-meb2", {
    discovery = discovery.handle_discovery,
    lifecycle_handlers = {
        added = device_added,
        init = device_init,
        removed = device_removed,
        infoChanged = device_info_changed
    },
    capability_handlers = {
        [capabilities.switch.ID] = {
            [capabilities.switch.commands.on.NAME] = handle_on,
            [capabilities.switch.commands.off.NAME] = handle_off
        },
        [controls.ID] = {
            [controls.commands.setAirPurifierMode.NAME] = handle_set_air_purifier_mode,
            [controls.commands.setFanLevel.NAME] = handle_set_fan_level,
            [controls.commands.setDisplayBrightness.NAME] = handle_set_display_brightness,
            [controls.commands.setPlasma.NAME] = handle_set_plasma,
            [controls.commands.setUv.NAME] = handle_set_uv,
            [controls.commands.setBuzzer.NAME] = handle_set_buzzer,
            [controls.commands.setChildLock.NAME] = handle_set_child_lock
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
