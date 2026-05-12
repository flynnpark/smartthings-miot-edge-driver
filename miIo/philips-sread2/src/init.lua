-- Philips Smart Desk Lamp 2 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local socket = require "socket"
local discovery = require "discovery"
local miio = require "miio"

local lightMode = capabilities["concertmirror08464.philipsLightMode"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60

-- miIO model: philips.light.sread2
-- python-miio PhilipsEyecare supports philips.light.sread1 and philips.light.sread2.
-- Core read properties: power, bright, scene
-- Core write methods: set_power, set_bright, set_scene
local MODE_TO_ST = {
    [0] = "none",
    [1] = "childReading",
    [2] = "adultReading",
    [3] = "computer"
}
local ST_TO_MODE = {
    none = 0,
    childReading = 1,
    adultReading = 2,
    computer = 3
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

    local power = miio.get_prop(device, ip, token, "power")
    if power then
        device:emit_event(power == "on" and capabilities.switch.switch.on() or capabilities.switch.switch.off())
    end
    socket.sleep(0.5)

    local bright = miio.get_prop(device, ip, token, "bright")
    if bright and type(bright) == "number" then
        device:emit_event(capabilities.switchLevel.level(bright))
    end
    socket.sleep(0.5)

    local scene = miio.get_prop(device, ip, token, "scene")
    local mode = MODE_TO_ST[scene]
    if mode then
        device:emit_event(lightMode.lightMode({value = mode}))
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

    local level = math.max(1, math.min(100, command.args.level))
    if miio.set_prop(device, ip, token, "set_bright", {level}) then
        device:emit_event(capabilities.switchLevel.level(level))
    end
end

local function set_light_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local scene = ST_TO_MODE[mode]
    if scene == nil then return end

    if miio.set_prop(device, ip, token, "set_scene", {scene}) then
        device:emit_event(lightMode.lightMode({value = mode}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.switchLevel.level(0))
    device:emit_event(lightMode.lightMode({value = "none"}))
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

local driver = Driver("philips-sread2", {
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
        [lightMode.ID] = {
            [lightMode.commands.setLightMode.NAME] = set_light_mode_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
