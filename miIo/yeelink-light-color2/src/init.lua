-- Yeelight Color Bulb V2 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miio = require "miio"

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local COLOR_TEMPERATURE_MIN = 1700
local COLOR_TEMPERATURE_MAX = 6500

-- miIO model: yeelink.light.color2
-- Core read properties: power, bright, ct, rgb
-- Core write methods: set_power, set_bright, set_ct_abx, set_rgb

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function rgb_to_hs(rgb)
    local r = math.floor(rgb / 65536) % 256
    local g = math.floor(rgb / 256) % 256
    local b = rgb % 256
    local rn = r / 255
    local gn = g / 255
    local bn = b / 255
    local maxc = math.max(rn, gn, bn)
    local minc = math.min(rn, gn, bn)
    local delta = maxc - minc
    local hue = 0

    if delta ~= 0 then
        if maxc == rn then
            hue = ((gn - bn) / delta) % 6
        elseif maxc == gn then
            hue = ((bn - rn) / delta) + 2
        else
            hue = ((rn - gn) / delta) + 4
        end
        hue = hue * 60
    end

    local saturation = 0
    if maxc ~= 0 then
        saturation = delta / maxc
    end

    return clamp(hue / 3.6, 0, 100), clamp(saturation * 100, 0, 100)
end

local function hs_to_rgb(hue, saturation)
    local h = (clamp(hue, 0, 100) * 3.6) % 360
    local s = clamp(saturation, 0, 100) / 100
    local v = 1
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0

    if h < 60 then
        r, g, b = c, x, 0
    elseif h < 120 then
        r, g, b = x, c, 0
    elseif h < 180 then
        r, g, b = 0, c, x
    elseif h < 240 then
        r, g, b = 0, x, c
    elseif h < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end

    local ri = math.floor((r + m) * 255 + 0.5)
    local gi = math.floor((g + m) * 255 + 0.5)
    local bi = math.floor((b + m) * 255 + 0.5)
    return ri * 65536 + gi * 256 + bi
end

local function get_properties(device, ip, token)
    local response = miio.cmd(device, ip, token, "get_prop", {"power", "bright", "ct", "rgb"})
    local result = response and response.result or {}
    return {
        power = result[1],
        bright = result[2],
        ct = result[3],
        rgb = result[4]
    }
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

    if values.bright and type(values.bright) == "number" then
        device:emit_event(capabilities.switchLevel.level(values.bright))
    end

    if values.ct and type(values.ct) == "number" then
        device:emit_event(capabilities.colorTemperature.colorTemperature({value = values.ct, unit = "K"}))
    end

    if values.rgb and type(values.rgb) == "number" then
        local hue, saturation = rgb_to_hs(values.rgb)
        device:emit_event(capabilities.colorControl.hue(hue))
        device:emit_event(capabilities.colorControl.saturation(saturation))
        device:emit_event(capabilities.colorControl.color({hue = hue, saturation = saturation}))
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

local function set_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = command.args.level
    if level <= 0 then
        if miio.set_prop(device, ip, token, "set_power", {"off"}) then
            device:emit_event(capabilities.switch.switch.off())
            device:emit_event(capabilities.switchLevel.level(0))
        end
        return
    end

    level = clamp(level, 1, 100)
    miio.set_prop(device, ip, token, "set_power", {"on"})
    if miio.set_prop(device, ip, token, "set_bright", {level}) then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(capabilities.switchLevel.level(level))
    end
end

local function set_color_temperature_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local temperature = clamp(command.args.temperature, COLOR_TEMPERATURE_MIN, COLOR_TEMPERATURE_MAX)
    miio.set_prop(device, ip, token, "set_power", {"on"})
    if miio.set_prop(device, ip, token, "set_ct_abx", {temperature, "smooth", 500}) then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(capabilities.colorTemperature.colorTemperature({value = temperature, unit = "K"}))
    end
end

local function set_color_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local color = command.args.color
    local hue = color.hue or 0
    local saturation = color.saturation or 0
    local rgb = hs_to_rgb(hue, saturation)
    miio.set_prop(device, ip, token, "set_power", {"on"})
    if miio.set_prop(device, ip, token, "set_rgb", {rgb}) then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(capabilities.colorControl.hue(hue))
        device:emit_event(capabilities.colorControl.saturation(saturation))
        device:emit_event(capabilities.colorControl.color({hue = hue, saturation = saturation}))
    end
end

local function set_hue_handler(_, device, command)
    local saturation = 100
    if device.state_cache and device.state_cache.main and device.state_cache.main.colorControl and device.state_cache.main.colorControl.saturation then
        saturation = device.state_cache.main.colorControl.saturation.value or saturation
    end
    set_color_handler(nil, device, {args = {color = {hue = command.args.hue, saturation = saturation}}})
end

local function set_saturation_handler(_, device, command)
    local hue = 0
    if device.state_cache and device.state_cache.main and device.state_cache.main.colorControl and device.state_cache.main.colorControl.hue then
        hue = device.state_cache.main.colorControl.hue.value or hue
    end
    set_color_handler(nil, device, {args = {color = {hue = hue, saturation = command.args.saturation}}})
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.switchLevel.level(0))
    device:emit_event(capabilities.colorTemperature.colorTemperatureRange({
        value = {minimum = COLOR_TEMPERATURE_MIN, maximum = COLOR_TEMPERATURE_MAX, step = 1},
        unit = "K"
    }))
    device:emit_event(capabilities.colorTemperature.colorTemperature({value = 4000, unit = "K"}))
    device:emit_event(capabilities.colorControl.hue(0))
    device:emit_event(capabilities.colorControl.saturation(100))
    device:emit_event(capabilities.colorControl.color({hue = 0, saturation = 100}))
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

local driver = Driver("miio-yeelink-light-color2", {
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
        [capabilities.switchLevel.ID] = {
            [capabilities.switchLevel.commands.setLevel.NAME] = set_level_handler
        },
        [capabilities.colorTemperature.ID] = {
            [capabilities.colorTemperature.commands.setColorTemperature.NAME] = set_color_temperature_handler
        },
        [capabilities.colorControl.ID] = {
            [capabilities.colorControl.commands.setColor.NAME] = set_color_handler,
            [capabilities.colorControl.commands.setHue.NAME] = set_hue_handler,
            [capabilities.colorControl.commands.setSaturation.NAME] = set_saturation_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
