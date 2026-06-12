-- Mijia Smart Desktop Air Circulation Fan Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local fanControls = capabilities["concertmirror08464.xiaomiFanP69Controls"]

local fanSpeedPercent = capabilities["fanSpeedPercent"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "xiaomi-fan-p69"

-- MIoT model: xiaomi.fan.p69
-- Source: real device LAN response, MIoT spec xiaomi-p69 v1, and user device report.
-- Fan service (siid=2)
local FAN_SIID = 2
local POWER_PIID = 1
local FAULT_PIID = 2              -- R 0=No fault, diagnostic only
local MODE_PIID = 3               -- RW 0=Straight, 1=Natural
local GEAR_FAN_LEVEL_PIID = 4     -- RW level bucket 0..3, not exposed separately
local FAN_SPEED_PIID = 5          -- RW stepless fan level 1..100
local HORIZONTAL_SWING_PIID = 6   -- RW horizontal oscillation on/off
local HORIZONTAL_ANGLE_PIID = 7   -- RW 30, 60, 90, 120
local VERTICAL_SWING_PIID = 8     -- RW vertical oscillation on/off
local VERTICAL_ANGLE_PIID = 9     -- RW 30, 60, 90, 100

-- Fan actions (siid=2), not exposed because switch and oscillation controls cover core use.
local TOGGLE_ACTION_IID = 3
local TURN_LEFT_ACTION_IID = 4
local TURN_RIGHT_ACTION_IID = 5
local TURN_UPWARD_ACTION_IID = 6
local TURN_DOWNWARD_ACTION_IID = 7

-- Indicator light service (siid=5)
local INDICATOR_LIGHT_SIID = 5
local INDICATOR_LIGHT_PIID = 1    -- RW on/off

-- Alarm service (siid=7)
local BUZZER_SIID = 7
local BUZZER_PIID = 1             -- RW alarm/buzzer on/off

-- Physical controls locked service (siid=8)
local CHILD_LOCK_SIID = 8
local CHILD_LOCK_PIID = 1         -- RW child lock on/off

-- Delay service (siid=9)
local DELAY_SIID = 9
local DELAY_ENABLED_PIID = 1      -- RW delay on/off, not exposed
local DELAY_TIME_PIID = 2         -- RW countdown minutes, not exposed
local DELAY_REMAIN_TIME_PIID = 4  -- R countdown minutes, not exposed

-- Xiaomi dm-service (siid=11), shortcut actions are not exposed.
local DM_SERVICE_SIID = 11
local TOGGLE_MODE_ACTION_IID = 1
local LOOP_GEAR_ACTION_IID = 2

local MODE_TO_ST = {
    [0] = "normal",
    [1] = "nature"
}

local ST_TO_MODE = {
    normal = 0,
    nature = 1
}

local SUPPORTED_OSCILLATION_MODES = {"off", "horizontal", "vertical", "all"}

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

local ANGLE_PROPERTIES = {
    {siid = 2, piid = 7, attr = fanControls.horizontalAngle},
    {siid = 2, piid = 9, attr = fanControls.verticalAngle}
}

local function emit_angle_event(device, siid, piid, value)
    if type(value) ~= "number" then return end
    for _, property in ipairs(ANGLE_PROPERTIES) do
        if property.siid == siid and property.piid == piid then
            device:emit_event(property.attr({value = math.floor(value)}))
            return
        end
    end
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
        {siid = FAN_SIID, piid = HORIZONTAL_ANGLE_PIID},
        {siid = FAN_SIID, piid = VERTICAL_SWING_PIID},
        {siid = FAN_SIID, piid = VERTICAL_ANGLE_PIID},
        {siid = INDICATOR_LIGHT_SIID, piid = INDICATOR_LIGHT_PIID},
        {siid = BUZZER_SIID, piid = BUZZER_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID}
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

            if siid == FAN_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(fanControls.fanMode({value = mode}))
                    end
                elseif piid == FAN_SPEED_PIID then
                    device:emit_event(fanSpeedPercent.percent({value = value, unit = "%"}))
                elseif piid == HORIZONTAL_SWING_PIID then
                    horizontal_swing = value
                elseif piid == HORIZONTAL_ANGLE_PIID then
                    emit_angle_event(device, siid, piid, value)
                elseif piid == VERTICAL_SWING_PIID then
                    vertical_swing = value
                elseif piid == VERTICAL_ANGLE_PIID then
                    emit_angle_event(device, siid, piid, value)
                end
            elseif siid == INDICATOR_LIGHT_SIID and piid == INDICATOR_LIGHT_PIID then
                emit_on_off(device, fanControls.indicatorLight, value)
            elseif siid == BUZZER_SIID and piid == BUZZER_PIID then
                emit_on_off(device, fanControls.buzzer, value)
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                emit_on_off(device, fanControls.childLock, value)
            end
        end
    end

    if horizontal_swing ~= nil or vertical_swing ~= nil then
        local mode = "off"
        if horizontal_swing and vertical_swing then
            mode = "all"
        elseif horizontal_swing then
            mode = "horizontal"
        elseif vertical_swing then
            mode = "vertical"
        end
        device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(mode))
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

local function set_fan_speed_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local speed = math.max(1, math.min(100, command.args.percent))
    local ok = pcall(miot.set, device, ip, token, FAN_SIID, FAN_SPEED_PIID, speed)
    if ok then
        device:emit_event(fanSpeedPercent.percent({value = speed, unit = "%"}))
    end
end

local function set_fan_oscillation_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.fanOscillationMode
    if mode ~= "off" and mode ~= "horizontal" and mode ~= "vertical" and mode ~= "all" then return end

    local horizontal = mode == "horizontal" or mode == "all"
    local vertical = mode == "vertical" or mode == "all"
    local ok_horizontal = pcall(miot.set, device, ip, token, FAN_SIID, HORIZONTAL_SWING_PIID, horizontal)
    local ok_vertical = pcall(miot.set, device, ip, token, FAN_SIID, VERTICAL_SWING_PIID, vertical)
    if ok_horizontal and ok_vertical then
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
    local ok = pcall(miot.set, device, ip, token, INDICATOR_LIGHT_SIID, INDICATOR_LIGHT_PIID, indicator_light == "on")
    if ok then
        device:emit_event(fanControls.indicatorLight({value = indicator_light}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local buzzer = command.args.buzzer
    local ok = pcall(miot.set, device, ip, token, BUZZER_SIID, BUZZER_PIID, buzzer == "on")
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

local function set_horizontal_angle_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local angle = math.floor(command.args.horizontalAngle)
    local ok = pcall(miot.set, device, ip, token, 2, 7, angle)
    if ok then
        device:emit_event(fanControls.horizontalAngle({value = angle}))
    end
end

local function set_vertical_angle_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local angle = math.floor(command.args.verticalAngle)
    local ok = pcall(miot.set, device, ip, token, 2, 9, angle)
    if ok then
        device:emit_event(fanControls.verticalAngle({value = angle}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(fanSpeedPercent.percent({value = 1, unit = "%"}))
    device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes({value = SUPPORTED_OSCILLATION_MODES}))
    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode("off"))
    device:emit_event(fanControls.fanMode({value = "normal"}))
    device:emit_event(fanControls.indicatorLight({value = "on"}))
    device:emit_event(fanControls.buzzer({value = "off"}))
    device:emit_event(fanControls.childLock({value = "off"}))
    device:emit_event(fanControls.horizontalAngle({value = 30}))
    device:emit_event(fanControls.verticalAngle({value = 30}))
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

local driver = Driver("miot-xiaomi-fan-p69", {
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
        [fanSpeedPercent.ID] = {
            [fanSpeedPercent.commands.setPercent.NAME] = set_fan_speed_handler
        },
        [capabilities.fanOscillationMode.ID] = {
            [capabilities.fanOscillationMode.commands.setFanOscillationMode.NAME] = set_fan_oscillation_mode_handler
        },
        [fanControls.ID] = {
            [fanControls.commands.setFanMode.NAME] = set_fan_mode_handler,
            [fanControls.commands.setIndicatorLight.NAME] = set_indicator_light_handler,
            [fanControls.commands.setBuzzer.NAME] = set_buzzer_handler,
            [fanControls.commands.setChildLock.NAME] = set_child_lock_handler,
            [fanControls.commands.setHorizontalAngle.NAME] = set_horizontal_angle_handler,
            [fanControls.commands.setVerticalAngle.NAME] = set_vertical_angle_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
