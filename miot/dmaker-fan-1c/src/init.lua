-- Xiaomi Fan 1C Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local fanControls = capabilities["concertmirror08464.xiaomiFan1cControls"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "dmaker-fan-1c"

-- MIoT model: dmaker.fan.1c
-- Source: python-miio FanMiot Fan1C mapping and MIoT spec dmaker-1c v1.
-- Fan service (siid=2)
local FAN_SIID = 2
local POWER_PIID = 1
local FAN_LEVEL_PIID = 2          -- 1..3
local SWING_MODE_PIID = 3         -- horizontal oscillation on/off
local MODE_PIID = 7               -- 0=Normal, 1=Sleep
local POWER_OFF_TIME_PIID = 10    -- read/write countdown minutes; not exposed
local BUZZER_PIID = 11            -- on/off
local INDICATOR_LIGHT_PIID = 12   -- on/off

-- Physical controls locked service (siid=3)
local CHILD_LOCK_SIID = 3
local CHILD_LOCK_PIID = 1

local MODE_TO_ST = {
    [0] = "normal",
    [1] = "sleep"
}

local ST_TO_MODE = {
    normal = 0,
    sleep = 1
}

local SUPPORTED_OSCILLATION_MODES = {"off", "horizontal"}

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(fanControls.ID) then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function emit_on_off(device, capability_attr, value)
    device:emit_event(capability_attr({value = value and "on" or "off"}))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = FAN_SIID, piid = POWER_PIID},
        {siid = FAN_SIID, piid = FAN_LEVEL_PIID},
        {siid = FAN_SIID, piid = SWING_MODE_PIID},
        {siid = FAN_SIID, piid = MODE_PIID},
        {siid = FAN_SIID, piid = POWER_OFF_TIME_PIID},
        {siid = FAN_SIID, piid = BUZZER_PIID},
        {siid = FAN_SIID, piid = INDICATOR_LIGHT_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID}
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

            if siid == FAN_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == FAN_LEVEL_PIID then
                    device:emit_event(fanControls.fanLevel({value = value}))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(fanControls.fanMode({value = mode}))
                    end
                elseif piid == SWING_MODE_PIID then
                    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(value and "horizontal" or "off"))
                elseif piid == INDICATOR_LIGHT_PIID then
                    emit_on_off(device, fanControls.indicatorLight, value)
                elseif piid == BUZZER_PIID then
                    emit_on_off(device, fanControls.buzzer, value)
                end
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                emit_on_off(device, fanControls.childLock, value)
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

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_fan_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = math.max(1, math.min(3, command.args.level))
    local ok = pcall(miot.set, device, ip, token, FAN_SIID, FAN_LEVEL_PIID, level)
    if ok then
        device:emit_event(fanControls.fanLevel({value = level}))
    end
end

local function set_fan_oscillation_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.fanOscillationMode
    if mode ~= "off" and mode ~= "horizontal" then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, SWING_MODE_PIID, mode == "horizontal")
    if ok then
        device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(mode))
    end
end

local function set_fan_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(fanControls.fanMode({value = mode}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator_light = command.args.indicatorLight
    local ok = pcall(miot.set, device, ip, token, FAN_SIID, INDICATOR_LIGHT_PIID, indicator_light == "on")
    if ok then
        device:emit_event(fanControls.indicatorLight({value = indicator_light}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local buzzer = command.args.buzzer
    local ok = pcall(miot.set, device, ip, token, FAN_SIID, BUZZER_PIID, buzzer == "on")
    if ok then
        device:emit_event(fanControls.buzzer({value = buzzer}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    local ok = pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, child_lock == "on")
    if ok then
        device:emit_event(fanControls.childLock({value = child_lock}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(fanControls.fanLevel({value = 1}))
    device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes({value = SUPPORTED_OSCILLATION_MODES}))
    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode("off"))
    device:emit_event(fanControls.fanMode({value = "normal"}))
    device:emit_event(fanControls.indicatorLight({value = "on"}))
    device:emit_event(fanControls.buzzer({value = "off"}))
    device:emit_event(fanControls.childLock({value = "off"}))
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

local driver = Driver("miot-dmaker-fan-1c", {
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
        [capabilities.fanOscillationMode.ID] = {
            [capabilities.fanOscillationMode.commands.setFanOscillationMode.NAME] = set_fan_oscillation_mode_handler
        },
        [fanControls.ID] = {
            [fanControls.commands.setFanLevel.NAME] = set_fan_level_handler,
            [fanControls.commands.setFanMode.NAME] = set_fan_mode_handler,
            [fanControls.commands.setIndicatorLight.NAME] = set_indicator_light_handler,
            [fanControls.commands.setBuzzer.NAME] = set_buzzer_handler,
            [fanControls.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
