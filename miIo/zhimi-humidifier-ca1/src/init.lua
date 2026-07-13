-- Zhimi Humidifier CA1 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miio = require "miio"

local humidifierCore = capabilities["concertmirror08464.zhimiHumidifierClassicCore"]
local humidifierWater = capabilities["concertmirror08464.zhimiHumidifierClassicWater"]
local deviceControls = capabilities["concertmirror08464.xiaomiDeviceControls"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60

-- miIO model: zhimi.humidifier.ca1
-- Core read properties: power, mode, humidity, buzzer, led_b, child_lock, limit_hum, temp_dec, speed, depth, dry
-- Core write methods: set_power, set_mode, set_limit_hum, set_dry, set_led_b, set_buzzer, set_child_lock
-- python-miio notes CA1 is limited to one get_prop item per request.
local STATUS_PROPERTIES = {
    "power",
    "mode",
    "humidity",
    "buzzer",
    "led_b",
    "child_lock",
    "limit_hum",
    "temp_dec",
    "speed",
    "depth",
    "dry"
}

local SUPPORTED_MODES = {"silent", "medium", "high", "auto", "strong"}
local SUPPORTED_HUMIDITIES = {30, 40, 50, 60, 70, 80}
local LED_BRIGHTNESS_TO_ST = {
    [0] = "bright",
    [1] = "dim",
    [2] = "off"
}
local ST_TO_LED_BRIGHTNESS = {
    bright = 0,
    dim = 1,
    off = 2
}

local function miio_on_off_to_st(value)
    if value == "on" or value == true then
        return "on"
    elseif value == "off" or value == false then
        return "off"
    end
    return nil
end

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function get_properties(device, ip, token)
    local values = {}

    for _, property in ipairs(STATUS_PROPERTIES) do
        values[property] = miio.get_prop(device, ip, token, property)
    end

    return values
end

local function normalize_target_humidity(humidity)
    local rounded = math.floor((humidity + 5) / 10) * 10
    if rounded < SUPPORTED_HUMIDITIES[1] then return SUPPORTED_HUMIDITIES[1] end
    if rounded > SUPPORTED_HUMIDITIES[#SUPPORTED_HUMIDITIES] then return SUPPORTED_HUMIDITIES[#SUPPORTED_HUMIDITIES] end
    return rounded
end

local function water_level_from_depth(depth)
    if type(depth) ~= "number" or depth > 125 then
        return nil
    end
    if depth < 0 then
        return 0
    end
    return math.floor(math.min(depth / 1.2, 100))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local ok, values = pcall(get_properties, device, ip, token)
    if not ok then
        return
    end

    if values.power then
        device:emit_event(values.power == "on" and capabilities.switch.switch.on() or capabilities.switch.switch.off())
    end

    if values.mode then
        device:emit_event(humidifierCore.fanMode({value = values.mode}))
    end

    if values.humidity and type(values.humidity) == "number" then
        device:emit_event(capabilities.relativeHumidityMeasurement.humidity(values.humidity))
    end

    if values.temp_dec and type(values.temp_dec) == "number" then
        device:emit_event(capabilities.temperatureMeasurement.temperature({value = values.temp_dec / 10, unit = "C"}))
    end

    if values.limit_hum and type(values.limit_hum) == "number" then
        device:emit_event(humidifierCore.targetHumidity({value = values.limit_hum, unit = "%"}))
    end

    local water_level = water_level_from_depth(values.depth)
    if water_level then
        device:emit_event(humidifierWater.waterLevel({value = water_level, unit = "%"}))
    end

    local dry = miio_on_off_to_st(values.dry)
    if dry then
        device:emit_event(humidifierWater.dryMode({value = dry}))
    end

    local led_brightness = LED_BRIGHTNESS_TO_ST[values.led_b]
    if led_brightness then
        device:emit_event(deviceControls.ledBrightness({value = led_brightness}))
    end

    local buzzer = miio_on_off_to_st(values.buzzer)
    if buzzer then
        device:emit_event(deviceControls.buzzer({value = buzzer}))
    end

    local child_lock = miio_on_off_to_st(values.child_lock)
    if child_lock then
        device:emit_event(deviceControls.childLock({value = child_lock}))
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
    if ip and miio.set_prop(device, ip, token, "set_power", {"on"}) then
        device:emit_event(capabilities.switch.switch.on())
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function handle_off(_, device, _)
    local ip, token = get_device_config(device)
    if ip and miio.set_prop(device, ip, token, "set_power", {"off"}) then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function handle_set_fan_mode(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    if miio.set_prop(device, ip, token, "set_mode", {mode}) then
        device:emit_event(humidifierCore.fanMode({value = mode}))
    end
end

local function handle_set_target_humidity(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local humidity = normalize_target_humidity(command.args.humidity)
    if miio.set_prop(device, ip, token, "set_limit_hum", {humidity}) then
        device:emit_event(humidifierCore.targetHumidity({value = humidity, unit = "%"}))
    end
end

local function handle_set_dry_mode(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    if miio.set_prop(device, ip, token, "set_dry", {mode}) then
        device:emit_event(humidifierWater.dryMode({value = mode}))
    end
end

local function handle_set_led_brightness(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local brightness = command.args.brightness
    local led_b = ST_TO_LED_BRIGHTNESS[brightness]
    if led_b == nil then return end

    if miio.set_prop(device, ip, token, "set_led_b", {tostring(led_b)}) then
        device:emit_event(deviceControls.ledBrightness({value = brightness}))
    end
end

local function handle_set_buzzer(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local buzzer = command.args.buzzer
    if miio.set_prop(device, ip, token, "set_buzzer", {buzzer}) then
        device:emit_event(deviceControls.buzzer({value = buzzer}))
    end
end

local function handle_set_child_lock(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    if miio.set_prop(device, ip, token, "set_child_lock", {child_lock}) then
        device:emit_event(deviceControls.childLock({value = child_lock}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(humidifierCore.ID, "main") then
        device:try_update_metadata({profile = "zhimi-humidifier-ca1"})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(humidifierCore.fanMode({value = "auto"}))
    device:emit_event(humidifierCore.targetHumidity({value = 40, unit = "%"}))
    device:emit_event(humidifierWater.dryMode({value = "off"}))
    device:emit_event(humidifierWater.waterLevel({value = 0, unit = "%"}))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(deviceControls.ledBrightness({value = "bright"}))
    device:emit_event(deviceControls.buzzer({value = "off"}))
    device:emit_event(deviceControls.childLock({value = "off"}))
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

local driver = Driver("miio-humidifier-ca1", {
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
        [humidifierCore.ID] = {
            [humidifierCore.commands.setFanMode.NAME] = handle_set_fan_mode,
            [humidifierCore.commands.setTargetHumidity.NAME] = handle_set_target_humidity
        },
        [humidifierWater.ID] = {
            [humidifierWater.commands.setDryMode.NAME] = handle_set_dry_mode
        },
        [deviceControls.ID] = {
            [deviceControls.commands.setLedBrightness.NAME] = handle_set_led_brightness,
            [deviceControls.commands.setBuzzer.NAME] = handle_set_buzzer,
            [deviceControls.commands.setChildLock.NAME] = handle_set_child_lock
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
