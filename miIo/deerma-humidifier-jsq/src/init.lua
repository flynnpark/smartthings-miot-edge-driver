-- Mi Smart Antibacterial Humidifier Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miio = require "miio"

local modeCap = capabilities["concertmirror08464.deermaHumJsqMode"]
local targetHumidityCap = capabilities["concertmirror08464.deermaHumJsqTargetHumidity"]
local indicatorLightCap = capabilities["concertmirror08464.deermaHumJsqIndicatorLight"]
local buzzerCap = capabilities["concertmirror08464.deermaHumJsqBuzzer"]
local waterShortageCap = capabilities["concertmirror08464.deermaHumJsqWaterShortage"]
local tankAttachedCap = capabilities["concertmirror08464.deermaHumJsqTankAttached"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "deerma-humidifier-jsq"

-- miIO model: deerma.humidifier.jsq
-- Source: python-miio miio.integrations.deerma.humidifier.airhumidifier_mjjsq,
-- class AirHumidifierMjjsq(Device). status() uses
-- get_properties(properties, max_properties=1), so each property is read with
-- its own classic get_prop request.
-- Read properties: OnOff_State, TemperatureValue, Humidity_Value,
--                  HumiSet_Value, Humidifier_Gear, Led_State, TipSound_State,
--                  waterstatus, watertankstatus
-- Write methods: Set_OnOff [0|1], Set_HumidifierGears [1..4],
--                SetLedState [0|1], SetTipSound_Status [0|1],
--                Set_HumiValue [0..99]

local PROPERTIES = {
    "OnOff_State",
    "TemperatureValue",
    "Humidity_Value",
    "HumiSet_Value",
    "Humidifier_Gear",
    "Led_State",
    "TipSound_State",
    "waterstatus",
    "watertankstatus"
}

local GEAR_TO_ST = {
    [1] = "low",
    [2] = "medium",
    [3] = "high",
    [4] = "humidity"
}

local ST_TO_GEAR = {
    low = 1,
    medium = 2,
    high = 3,
    humidity = 4
}

local TARGET_HUMIDITY_MIN = 0
local TARGET_HUMIDITY_MAX = 99

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(tankAttachedCap.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
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

    if type(values.OnOff_State) == "number" then
        device:emit_event(capabilities.switch.switch(values.OnOff_State == 1 and "on" or "off"))
    end

    if type(values.TemperatureValue) == "number" then
        device:emit_event(capabilities.temperatureMeasurement.temperature({value = values.TemperatureValue, unit = "C"}))
    end

    if type(values.Humidity_Value) == "number" then
        device:emit_event(capabilities.relativeHumidityMeasurement.humidity(values.Humidity_Value))
    end

    if type(values.HumiSet_Value) == "number" then
        local target = clamp(math.floor(values.HumiSet_Value), TARGET_HUMIDITY_MIN, TARGET_HUMIDITY_MAX)
        device:emit_event(targetHumidityCap.targetHumidity({value = target, unit = "%"}))
    end

    if type(values.Humidifier_Gear) == "number" then
        local mode = GEAR_TO_ST[values.Humidifier_Gear]
        if mode then
            device:emit_event(modeCap.mode({value = mode}))
        end
    end

    if type(values.Led_State) == "number" then
        device:emit_event(indicatorLightCap.indicatorLight({value = values.Led_State == 1 and "on" or "off"}))
    end

    if type(values.TipSound_State) == "number" then
        device:emit_event(buzzerCap.buzzer({value = values.TipSound_State == 1 and "on" or "off"}))
    end

    if type(values.waterstatus) == "number" then
        device:emit_event(waterShortageCap.waterShortage({value = values.waterstatus == 0 and "shortage" or "normal"}))
    end

    if type(values.watertankstatus) == "number" then
        device:emit_event(tankAttachedCap.tankAttached({value = values.watertankstatus == 0 and "detached" or "attached"}))
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
    if ip and miio.set_prop(device, ip, token, "Set_OnOff", {1}) then
        device:emit_event(capabilities.switch.switch.on())
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function switch_off_handler(_, device, _)
    local ip, token = get_device_config(device)
    if ip and miio.set_prop(device, ip, token, "Set_OnOff", {0}) then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local gear = ST_TO_GEAR[mode]
    if gear == nil then return end

    if miio.set_prop(device, ip, token, "Set_HumidifierGears", {gear}) then
        device:emit_event(modeCap.mode({value = mode}))
    end
end

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local target = clamp(math.floor(command.args.targetHumidity + 0.5), TARGET_HUMIDITY_MIN, TARGET_HUMIDITY_MAX)
    if miio.set_prop(device, ip, token, "Set_HumiValue", {target}) then
        device:emit_event(targetHumidityCap.targetHumidity({value = target, unit = "%"}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator = command.args.indicatorLight
    if miio.set_prop(device, ip, token, "SetLedState", {indicator == "on" and 1 or 0}) then
        device:emit_event(indicatorLightCap.indicatorLight({value = indicator}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local buzzer = command.args.buzzer
    if miio.set_prop(device, ip, token, "SetTipSound_Status", {buzzer == "on" and 1 or 0}) then
        device:emit_event(buzzerCap.buzzer({value = buzzer}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(modeCap.mode({value = "low"}))
    device:emit_event(targetHumidityCap.targetHumidity({value = 50, unit = "%"}))
    device:emit_event(indicatorLightCap.indicatorLight({value = "on"}))
    device:emit_event(buzzerCap.buzzer({value = "off"}))
    device:emit_event(waterShortageCap.waterShortage({value = "normal"}))
    device:emit_event(tankAttachedCap.tankAttached({value = "attached"}))
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

local driver = Driver("miio-deerma-humidifier-jsq", {
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
        [targetHumidityCap.ID] = {
            [targetHumidityCap.commands.setTargetHumidity.NAME] = set_target_humidity_handler
        },
        [indicatorLightCap.ID] = {
            [indicatorLightCap.commands.setIndicatorLight.NAME] = set_indicator_light_handler
        },
        [buzzerCap.ID] = {
            [buzzerCap.commands.setBuzzer.NAME] = set_buzzer_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
