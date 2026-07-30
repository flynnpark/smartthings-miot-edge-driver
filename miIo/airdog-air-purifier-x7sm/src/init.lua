-- Airdog Air Purifier X7sm Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miio = require "miio"

local modeCap = capabilities["concertmirror08464.airdogAirX7smMode"]
local fanLevelCap = capabilities["concertmirror08464.airdogAirX7smFanLevel"]
local childLockCap = capabilities["concertmirror08464.airdogAirX7smChildLock"]
local cleanFilterCap = capabilities["concertmirror08464.airdogAirX7smCleanFilter"]
local hchoCap = capabilities["concertmirror08464.airdogAirX7smHcho"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "airdog-air-purifier-x7sm"
local CURRENT_MODE = "current_mode"
local CURRENT_FAN_LEVEL = "current_fan_level"

-- miIO model: airdog.airpurifier.x7sm
-- Source: python-miio miio.integrations.airdog.airpurifier.airpurifier_airdog,
-- class AirDogX3(Device), AVAILABLE_PROPERTIES entry adds hcho.
-- Read properties via get_prop: power, mode, speed, lock, clean, pm, hcho
-- Write methods:
--   set_power [0|1]
--   set_wind [modeIndex, speed]  modeIndex 0=auto, 1=manual, 2=sleep
--   set_lock [0|1]
--   set_clean (no argument, marks the filter as cleaned)
-- Mode auto and sleep always send speed 1. Manual speed range for x7sm is 1..5.

local PROPERTIES = {"power", "mode", "speed", "lock", "clean", "pm", "hcho"}

local MODE_TO_INDEX = {
    auto = 0,
    manual = 1,
    sleep = 2
}

local MAX_FAN_LEVEL = 5

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

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local response = miio.cmd(device, ip, token, "get_prop", PROPERTIES)
    if not response or not response.result then
        return
    end

    local values = {}
    for index, property in ipairs(PROPERTIES) do
        values[property] = response.result[index]
    end

    if values.power ~= nil then
        device:emit_event(capabilities.switch.switch(values.power == "on" and "on" or "off"))
    end

    if values.mode ~= nil and MODE_TO_INDEX[values.mode] ~= nil then
        device:set_field(CURRENT_MODE, values.mode)
        device:emit_event(modeCap.mode({value = values.mode}))
    end

    if type(values.speed) == "number" then
        local level = clamp(math.floor(values.speed), 1, MAX_FAN_LEVEL)
        device:set_field(CURRENT_FAN_LEVEL, level)
        device:emit_event(fanLevelCap.fanLevel({value = tostring(level)}))
    end

    if values.lock ~= nil then
        device:emit_event(childLockCap.childLock({value = values.lock == "lock" and "on" or "off"}))
    end

    if values.clean ~= nil then
        device:emit_event(cleanFilterCap.cleanFilter({value = values.clean == "y" and "needsCleaning" or "normal"}))
    end

    if type(values.pm) == "number" then
        device:emit_event(capabilities.fineDustSensor.fineDustLevel(values.pm))
    end

    if type(values.hcho) == "number" then
        device:emit_event(hchoCap.hcho({value = values.hcho}))
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

local function send_wind(device, ip, token, mode, level)
    local index = MODE_TO_INDEX[mode]
    if index == nil then
        return false
    end

    local speed = level
    if mode ~= "manual" then
        speed = 1
    end

    return miio.set_prop(device, ip, token, "set_wind", {index, speed})
end

local function switch_on_handler(_, device, _)
    local ip, token = get_device_config(device)
    if ip and miio.set_prop(device, ip, token, "set_power", {1}) then
        device:emit_event(capabilities.switch.switch.on())
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function switch_off_handler(_, device, _)
    local ip, token = get_device_config(device)
    if ip and miio.set_prop(device, ip, token, "set_power", {0}) then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    if MODE_TO_INDEX[mode] == nil then return end

    local level = device:get_field(CURRENT_FAN_LEVEL) or 1
    if send_wind(device, ip, token, mode, level) then
        device:set_field(CURRENT_MODE, mode)
        device:emit_event(modeCap.mode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_fan_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = tonumber(command.args.fanLevel)
    if not level then return end

    level = clamp(math.floor(level), 1, MAX_FAN_LEVEL)

    -- Speed only applies in manual mode, so setting a level switches the device
    -- to manual the same way the app does.
    if send_wind(device, ip, token, "manual", level) then
        device:set_field(CURRENT_MODE, "manual")
        device:set_field(CURRENT_FAN_LEVEL, level)
        device:emit_event(modeCap.mode({value = "manual"}))
        device:emit_event(fanLevelCap.fanLevel({value = tostring(level)}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    if miio.set_prop(device, ip, token, "set_lock", {child_lock == "on" and 1 or 0}) then
        device:emit_event(childLockCap.childLock({value = child_lock}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.fineDustSensor.fineDustLevel(0))
    device:emit_event(hchoCap.hcho({value = 0}))
    device:emit_event(modeCap.mode({value = "auto"}))
    device:emit_event(fanLevelCap.fanLevel({value = "1"}))
    device:emit_event(childLockCap.childLock({value = "off"}))
    device:emit_event(cleanFilterCap.cleanFilter({value = "normal"}))
    device:set_field(CURRENT_MODE, "auto")
    device:set_field(CURRENT_FAN_LEVEL, 1)
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

local driver = Driver("miio-airdog-airpurifier-x7sm", {
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
        [childLockCap.ID] = {
            [childLockCap.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
