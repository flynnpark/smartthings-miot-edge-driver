-- Mijia Smart DC Inverter Circulation Fan Pro Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "xiaomi-fan-p90"

-- Exact model: xiaomi.fan.p90.
-- The MIoT keys are verified against the MIoT spec and a real LAN get_properties response.
local FAN_SIID = 2
local POWER_PIID = 1
local MODE_PIID = 3
local FAN_SPEED_PIID = 4
local HORIZONTAL_SWING_PIID = 6
local VERTICAL_SWING_PIID = 8
local DISPLAY_SIID = 6
local BUZZER_SIID = 7
local CHILD_LOCK_SIID = 8
local AUXILIARY_PIID = 1

local MODE_TO_WIND_MODE = {
    [0] = "noWind",
    [1] = "naturalWind"
}

local WIND_MODE_TO_MODE = {
    noWind = 0,
    naturalWind = 1
}

local SUPPORTED_WIND_MODES = {"noWind", "naturalWind"}
local SUPPORTED_OSCILLATION_MODES = {"off", "horizontal", "vertical", "all"}

local SWITCH_PROPERTIES = {
    display = {siid = DISPLAY_SIID, piid = AUXILIARY_PIID},
    buzzer = {siid = BUZZER_SIID, piid = AUXILIARY_PIID},
    childLock = {siid = CHILD_LOCK_SIID, piid = AUXILIARY_PIID}
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
    if not device:supports_capability_by_id(capabilities.windMode.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function emit_switch_event(device, component_id, value)
    local event = capabilities.switch.switch(value and "on" or "off")
    if component_id == "main" then
        device:emit_event(event)
        return
    end
    device:emit_component_event(device.profile.components[component_id], event)
end

local function emit_oscillation_event(device, horizontal, vertical)
    local mode = "off"
    if horizontal and vertical then
        mode = "all"
    elseif horizontal then
        mode = "horizontal"
    elseif vertical then
        mode = "vertical"
    end
    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(mode))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = FAN_SIID, piid = POWER_PIID},
        {siid = FAN_SIID, piid = MODE_PIID},
        {siid = FAN_SIID, piid = FAN_SPEED_PIID},
        {siid = FAN_SIID, piid = HORIZONTAL_SWING_PIID},
        {siid = FAN_SIID, piid = VERTICAL_SWING_PIID},
        {siid = DISPLAY_SIID, piid = AUXILIARY_PIID},
        {siid = BUZZER_SIID, piid = AUXILIARY_PIID},
        {siid = CHILD_LOCK_SIID, piid = AUXILIARY_PIID}
    }

    local ok, response = pcall(miot.gets, device, ip, token, properties)
    if not ok or not response or not response.result then
        return
    end

    local horizontal_swing = nil
    local vertical_swing = nil

    for _, result in ipairs(response.result) do
        if result.code == 0 then
            local siid = result.siid
            local piid = result.piid
            local value = result.value

            if siid == FAN_SIID and piid == POWER_PIID then
                emit_switch_event(device, "main", value)
            elseif siid == FAN_SIID and piid == MODE_PIID then
                local wind_mode = MODE_TO_WIND_MODE[value]
                if wind_mode then
                    device:emit_event(capabilities.windMode.windMode({value = wind_mode}))
                end
            elseif siid == FAN_SIID and piid == FAN_SPEED_PIID then
                device:emit_event(capabilities.fanSpeedPercent.percent({value = value, unit = "%"}))
            elseif siid == FAN_SIID and piid == HORIZONTAL_SWING_PIID then
                horizontal_swing = value
            elseif siid == FAN_SIID and piid == VERTICAL_SWING_PIID then
                vertical_swing = value
            elseif siid == DISPLAY_SIID and piid == AUXILIARY_PIID then
                emit_switch_event(device, "display", value)
            elseif siid == BUZZER_SIID and piid == AUXILIARY_PIID then
                emit_switch_event(device, "buzzer", value)
            elseif siid == CHILD_LOCK_SIID and piid == AUXILIARY_PIID then
                emit_switch_event(device, "childLock", value)
            end
        end
    end

    if horizontal_swing ~= nil or vertical_swing ~= nil then
        emit_oscillation_event(device, horizontal_swing, vertical_swing)
    end
end

local function stop_polling_timer(device)
    local timer = device:get_field(POLLING_TIMER)
    if timer then
        device.thread:cancel_timer(timer)
        device:set_field(POLLING_TIMER, nil)
    end
end

local function start_polling_timer(device)
    local interval = device.preferences.pollingInterval or DEFAULT_POLLING_INTERVAL
    local timer = device.thread:call_on_schedule(interval, function()
        pcall(poll_device_status, device)
    end, "Polling")
    device:set_field(POLLING_TIMER, timer)
end

local function switch_on_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local property = SWITCH_PROPERTIES[command.component]
    local siid = property and property.siid or FAN_SIID
    local piid = property and property.piid or POWER_PIID
    local ok = pcall(miot.set, device, ip, token, siid, piid, true)
    if ok then
        emit_switch_event(device, command.component, true)
        if command.component == "main" then
            device.thread:call_with_delay(1, function()
                pcall(poll_device_status, device)
            end)
        end
    end
end

local function switch_off_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local property = SWITCH_PROPERTIES[command.component]
    local siid = property and property.siid or FAN_SIID
    local piid = property and property.piid or POWER_PIID
    local ok = pcall(miot.set, device, ip, token, siid, piid, false)
    if ok then
        emit_switch_event(device, command.component, false)
    end
end

local function set_fan_speed_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local speed = math.max(1, math.min(100, command.args.percent))
    local ok = pcall(miot.set, device, ip, token, FAN_SIID, FAN_SPEED_PIID, speed)
    if ok then
        device:emit_event(capabilities.fanSpeedPercent.percent({value = speed, unit = "%"}))
    end
end

local function set_wind_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local wind_mode = command.args.windMode
    local mode = WIND_MODE_TO_MODE[wind_mode]
    if mode == nil then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, MODE_PIID, mode)
    if ok then
        device:emit_event(capabilities.windMode.windMode({value = wind_mode}))
    end
end

local function set_fan_oscillation_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.fanOscillationMode
    if mode ~= "off" and mode ~= "horizontal" and mode ~= "vertical" and mode ~= "all" then return end

    local horizontal = mode == "horizontal" or mode == "all"
    local vertical = mode == "vertical" or mode == "all"
    local horizontal_ok = pcall(miot.set, device, ip, token, FAN_SIID, HORIZONTAL_SWING_PIID, horizontal)
    local vertical_ok = pcall(miot.set, device, ip, token, FAN_SIID, VERTICAL_SWING_PIID, vertical)
    if horizontal_ok and vertical_ok then
        emit_oscillation_event(device, horizontal, vertical)
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    emit_switch_event(device, "main", false)
    device:emit_event(capabilities.fanSpeedPercent.percent({value = 1, unit = "%"}))
    device:emit_event(capabilities.windMode.supportedWindModes({value = SUPPORTED_WIND_MODES}))
    device:emit_event(capabilities.windMode.windMode({value = "noWind"}))
    device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes({value = SUPPORTED_OSCILLATION_MODES}))
    emit_oscillation_event(device, false, false)
    emit_switch_event(device, "display", true)
    emit_switch_event(device, "buzzer", true)
    emit_switch_event(device, "childLock", false)
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

local driver = Driver("miot-xiaomi-fan-p90", {
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
        [capabilities.fanSpeedPercent.ID] = {
            [capabilities.fanSpeedPercent.commands.setPercent.NAME] = set_fan_speed_handler
        },
        [capabilities.windMode.ID] = {
            [capabilities.windMode.commands.setWindMode.NAME] = set_wind_mode_handler
        },
        [capabilities.fanOscillationMode.ID] = {
            [capabilities.fanOscillationMode.commands.setFanOscillationMode.NAME] = set_fan_oscillation_mode_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
