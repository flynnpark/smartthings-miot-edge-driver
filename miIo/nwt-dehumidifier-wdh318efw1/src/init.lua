-- Xiaomi Widetech Dehumidifier Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miio = require "miio"

local modeCap = capabilities["concertmirror08464.nwtDerhWdh318Mode"]
local fanLevelCap = capabilities["concertmirror08464.nwtDerhWdh318FanLevel"]
local targetHumidityCap = capabilities["concertmirror08464.nwtDerhWdh318TargetHumidity"]
local buzzerCap = capabilities["concertmirror08464.nwtDerhWdh318Buzzer"]
local childLockCap = capabilities["concertmirror08464.nwtDerhWdh318ChildLock"]
local indicatorLightCap = capabilities["concertmirror08464.nwtDerhWdh318IndicatorLight"]
local tankFullCap = capabilities["concertmirror08464.nwtDerhWdh318TankFull"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "nwt-dehumidifier-wdh318efw1"

-- miIO model: nwt.derh.wdh318efw1
-- Source: python-miio miio.integrations.nwt.dehumidifier.airdehumidifier,
-- class AirDehumidifier(Device). Its status() calls
-- get_properties(properties, max_properties=1), so each property is read with
-- its own `get_prop` request instead of one batched request.
-- Read properties: on_off, mode, buzzer, led, child_lock, humidity, temp,
--                  tank_full, fan_speed, auto
-- Write methods: set_power(on/off), set_mode(on/auto/dry_cloth),
--                set_fan_level(0..4), set_led(on/off), set_buzzer(on/off),
--                set_child_lock(on/off), set_auto(40/50/60)

local PROPERTIES = {
    "on_off",
    "mode",
    "buzzer",
    "led",
    "child_lock",
    "humidity",
    "temp",
    "tank_full",
    "fan_speed",
    "auto"
}

local MIIO_MODE_TO_ST = {
    on = "on",
    auto = "auto",
    dry_cloth = "dryCloth"
}

local ST_TO_MIIO_MODE = {
    on = "on",
    auto = "auto",
    dryCloth = "dry_cloth"
}

local FAN_SPEED_TO_ST = {
    [0] = "sleep",
    [1] = "low",
    [2] = "medium",
    [3] = "high",
    [4] = "strong"
}

local ST_TO_FAN_SPEED = {
    sleep = 0,
    low = 1,
    medium = 2,
    high = 3,
    strong = 4
}

local TARGET_HUMIDITY_VALUES = {
    ["40"] = 40,
    ["50"] = 50,
    ["60"] = 60
}

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(tankFullCap.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function on_off_to_bool(value)
    return value == "on" or value == true or value == 1
end

local function emit_on_off(device, capability_attr, value)
    device:emit_event(capability_attr({value = on_off_to_bool(value) and "on" or "off"}))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local values = {}
    for _, property in ipairs(PROPERTIES) do
        local response = miio.cmd(device, ip, token, "get_prop", {property})
        if response and response.result then
            values[property] = response.result[1]
        end
    end

    if values.on_off ~= nil then
        device:emit_event(capabilities.switch.switch(on_off_to_bool(values.on_off) and "on" or "off"))
    end

    if values.mode ~= nil then
        local mode = MIIO_MODE_TO_ST[values.mode]
        if mode then
            device:emit_event(modeCap.mode({value = mode}))
        end
    end

    if type(values.humidity) == "number" then
        device:emit_event(capabilities.relativeHumidityMeasurement.humidity(values.humidity))
    end

    if type(values.temp) == "number" then
        device:emit_event(capabilities.temperatureMeasurement.temperature({value = values.temp, unit = "C"}))
    end

    if type(values.fan_speed) == "number" then
        local level = FAN_SPEED_TO_ST[values.fan_speed]
        if level then
            device:emit_event(fanLevelCap.fanLevel({value = level}))
        end
    end

    if type(values.auto) == "number" then
        local target = tostring(values.auto)
        if TARGET_HUMIDITY_VALUES[target] then
            device:emit_event(targetHumidityCap.targetHumidity({value = target}))
        end
    end

    if values.tank_full ~= nil then
        device:emit_event(tankFullCap.tankFull({value = on_off_to_bool(values.tank_full) and "full" or "normal"}))
    end

    if values.buzzer ~= nil then
        emit_on_off(device, buzzerCap.buzzer, values.buzzer)
    end

    if values.child_lock ~= nil then
        emit_on_off(device, childLockCap.childLock, values.child_lock)
    end

    if values.led ~= nil then
        emit_on_off(device, indicatorLightCap.indicatorLight, values.led)
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
    if ip and miio.set_prop(device, ip, token, "set_power", {"on"}) then
        device:emit_event(capabilities.switch.switch.on())
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function switch_off_handler(_, device, _)
    local ip, token = get_device_config(device)
    if ip and miio.set_prop(device, ip, token, "set_power", {"off"}) then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local miio_mode = ST_TO_MIIO_MODE[mode]
    if not miio_mode then return end

    if miio.set_prop(device, ip, token, "set_mode", {miio_mode}) then
        device:emit_event(modeCap.mode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_fan_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = command.args.fanLevel
    local speed = ST_TO_FAN_SPEED[level]
    if speed == nil then return end

    if miio.set_prop(device, ip, token, "set_fan_level", {speed}) then
        device:emit_event(fanLevelCap.fanLevel({value = level}))
    end
end

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local target = command.args.targetHumidity
    local value = TARGET_HUMIDITY_VALUES[target]
    if not value then return end

    if miio.set_prop(device, ip, token, "set_auto", {value}) then
        device:emit_event(targetHumidityCap.targetHumidity({value = target}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local buzzer = command.args.buzzer
    if miio.set_prop(device, ip, token, "set_buzzer", {buzzer}) then
        device:emit_event(buzzerCap.buzzer({value = buzzer}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    if miio.set_prop(device, ip, token, "set_child_lock", {child_lock}) then
        device:emit_event(childLockCap.childLock({value = child_lock}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator = command.args.indicatorLight
    if miio.set_prop(device, ip, token, "set_led", {indicator}) then
        device:emit_event(indicatorLightCap.indicatorLight({value = indicator}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(modeCap.mode({value = "auto"}))
    device:emit_event(fanLevelCap.fanLevel({value = "medium"}))
    device:emit_event(targetHumidityCap.targetHumidity({value = "50"}))
    device:emit_event(tankFullCap.tankFull({value = "normal"}))
    device:emit_event(buzzerCap.buzzer({value = "off"}))
    device:emit_event(childLockCap.childLock({value = "off"}))
    device:emit_event(indicatorLightCap.indicatorLight({value = "on"}))
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

local driver = Driver("miio-nwt-derh-wdh318efw1", {
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
            [modeCap.commands.setMode.NAME] = set_mode_handler
        },
        [fanLevelCap.ID] = {
            [fanLevelCap.commands.setFanLevel.NAME] = set_fan_level_handler
        },
        [targetHumidityCap.ID] = {
            [targetHumidityCap.commands.setTargetHumidity.NAME] = set_target_humidity_handler
        },
        [buzzerCap.ID] = {
            [buzzerCap.commands.setBuzzer.NAME] = set_buzzer_handler
        },
        [childLockCap.ID] = {
            [childLockCap.commands.setChildLock.NAME] = set_child_lock_handler
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
