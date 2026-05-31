-- Yeelight Mono Bulb Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miio = require "miio"

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60

-- miIO model: yeelink.light.mono1
-- Core read properties: power, bright
-- Core write methods: set_power, set_bright

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

local function get_properties(device, ip, token)
    local response = miio.cmd(device, ip, token, "get_prop", {"power", "bright"})
    local result = response and response.result or {}
    return {
        power = result[1],
        bright = result[2]
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

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.switchLevel.level(0))
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

local driver = Driver("miio-yeelink-light-mono1", {
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
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
