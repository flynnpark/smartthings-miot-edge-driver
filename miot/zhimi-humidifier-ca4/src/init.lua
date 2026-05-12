-- Zhimi Humidifier CA4 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local ca4Core = capabilities["concertmirror08464.zhimiHumidifierCa4Core"]
local deviceControls = capabilities["concertmirror08464.xiaomiDeviceControls"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60

-- MIoT model: zhimi.humidifier.ca4
-- Source: python-miio AirHumidifierMiot _MAPPINGS_CA4
local HUMIDIFIER_SIID = 2
local ENVIRONMENT_SIID = 3

-- Air Humidifier service (siid=2)
local POWER_PIID = 1
local MODE_PIID = 5              -- 0=Auto, 1=Low, 2=Mid, 3=High
local TARGET_HUMIDITY_PIID = 6   -- 30..80 %
local WATER_LEVEL_PIID = 7       -- 0..128
local AUTO_DRY_PIID = 8

-- Environment service (siid=3)
local TEMPERATURE_PIID = 7
local HUMIDITY_PIID = 9

-- Alarm / indicator / physical control locked services
local BUZZER_SIID = 4
local BUZZER_PIID = 1
local LED_BRIGHTNESS_SIID = 5
local LED_BRIGHTNESS_PIID = 2    -- 0=Off, 1=Dim, 2=Bright
local CHILD_LOCK_SIID = 6
local CHILD_LOCK_PIID = 1

local MODE_TO_ST = {
    [0] = "auto",
    [1] = "low",
    [2] = "mid",
    [3] = "high"
}

local ST_TO_MODE = {
    auto = 0,
    low = 1,
    mid = 2,
    high = 3
}

local LED_BRIGHTNESS_TO_ST = {
    [0] = "off",
    [1] = "dim",
    [2] = "bright"
}

local ST_TO_LED_BRIGHTNESS = {
    off = 0,
    dim = 1,
    bright = 2
}

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
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
        {siid = HUMIDIFIER_SIID, piid = AUTO_DRY_PIID},
        {siid = BUZZER_SIID, piid = BUZZER_PIID},
        {siid = LED_BRIGHTNESS_SIID, piid = LED_BRIGHTNESS_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = ENVIRONMENT_SIID, piid = TEMPERATURE_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID}
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
                        device:emit_event(ca4Core.fanMode({value = mode}))
                    end
                elseif piid == TARGET_HUMIDITY_PIID then
                    device:emit_event(ca4Core.targetHumidity({value = value, unit = "%"}))
                elseif piid == WATER_LEVEL_PIID then
                    device:emit_event(ca4Core.waterLevel({value = value, unit = "%"}))
                elseif piid == AUTO_DRY_PIID then
                    device:emit_event(ca4Core.dryMode({value = value and "on" or "off"}))
                end
            elseif siid == BUZZER_SIID and piid == BUZZER_PIID then
                device:emit_event(deviceControls.buzzer({value = value and "on" or "off"}))
            elseif siid == LED_BRIGHTNESS_SIID and piid == LED_BRIGHTNESS_PIID then
                local brightness = LED_BRIGHTNESS_TO_ST[value]
                if brightness then
                    device:emit_event(deviceControls.ledBrightness({value = brightness}))
                end
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(deviceControls.childLock({value = value and "on" or "off"}))
            elseif siid == ENVIRONMENT_SIID then
                if piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == HUMIDITY_PIID then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
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

local function set_fan_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(ca4Core.fanMode({value = mode}))
    end
end

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local humidity = math.max(30, math.min(80, command.args.humidity))
    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, TARGET_HUMIDITY_PIID, humidity)
    if ok then
        device:emit_event(ca4Core.targetHumidity({value = humidity, unit = "%"}))
    end
end

local function set_dry_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local ok = pcall(miot.set, device, ip, token, HUMIDIFIER_SIID, AUTO_DRY_PIID, mode == "on")
    if ok then
        device:emit_event(ca4Core.dryMode({value = mode}))
    end
end

local function set_led_brightness_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local brightness = command.args.brightness
    local value = ST_TO_LED_BRIGHTNESS[brightness]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, LED_BRIGHTNESS_SIID, LED_BRIGHTNESS_PIID, value)
    if ok then
        device:emit_event(deviceControls.ledBrightness({value = brightness}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local value = command.args.buzzer == "on"
    local ok = pcall(miot.set, device, ip, token, BUZZER_SIID, BUZZER_PIID, value)
    if ok then
        device:emit_event(deviceControls.buzzer({value = command.args.buzzer}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local value = command.args.childLock == "on"
    local ok = pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, value)
    if ok then
        device:emit_event(deviceControls.childLock({value = command.args.childLock}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(ca4Core.fanMode({value = "auto"}))
    device:emit_event(ca4Core.targetHumidity({value = 50, unit = "%"}))
    device:emit_event(ca4Core.waterLevel({value = 0, unit = "%"}))
    device:emit_event(ca4Core.dryMode({value = "off"}))
    device:emit_event(deviceControls.ledBrightness({value = "bright"}))
    device:emit_event(deviceControls.buzzer({value = "off"}))
    device:emit_event(deviceControls.childLock({value = "off"}))
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

local driver = Driver("miot-humidifier-ca4", {
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
        [ca4Core.ID] = {
            [ca4Core.commands.setFanMode.NAME] = set_fan_mode_handler,
            [ca4Core.commands.setTargetHumidity.NAME] = set_target_humidity_handler,
            [ca4Core.commands.setDryMode.NAME] = set_dry_mode_handler
        },
        [deviceControls.ID] = {
            [deviceControls.commands.setLedBrightness.NAME] = set_led_brightness_handler,
            [deviceControls.commands.setBuzzer.NAME] = set_buzzer_handler,
            [deviceControls.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
