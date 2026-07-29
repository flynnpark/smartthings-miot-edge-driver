-- Zhimi Fan FA2 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local fanLevelCap = capabilities["concertmirror08464.zhimiFanFa2FanLevel"]
local fanModeCap = capabilities["concertmirror08464.zhimiFanFa2FanMode"]
local hAngleCap = capabilities["concertmirror08464.zhimiFanFa2HorizontalAngleV2"]
local vAngleCap = capabilities["concertmirror08464.zhimiFanFa2VerticalAngleV2"]
local indicatorCap = capabilities["concertmirror08464.zhimiFanFa2Indicator"]
local buzzerCap = capabilities["concertmirror08464.zhimiFanFa2Buzzer"]
local childLockCap = capabilities["concertmirror08464.zhimiFanFa2ChildLock"]
local motorSpeedCap = capabilities["concertmirror08464.zhimiFanFa2MotorSpeed"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "zhimi-fan-fa2"

-- MIoT model: zhimi.fan.fa2
-- specModel: zhimi-fa2
-- URN: urn:miot-spec-v2:device:fan:0000A005:zhimi-fa2:1
--
-- Fan service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fan-level, uint8, RW enum: 1..4
--   piid=3 horizontal-swing, bool, RW
--   piid=12 horizontal-angle, uint16, RW range 0..120
--   piid=14 vertical-angle, uint8, RW range 0..100
--   piid=7 mode, uint8, RW enum: 0=natural, 1=straight, 2=temp wind
--   piid=10 brightness, uint8, RW range 0..1 (indicator light on/off)
--   piid=11 alarm, bool, RW
--   piid=4 vertical-swing shares the same vane the vertical angle already
--     sets, and piid=8 status plus piid=9 fault report idle/busy and a stuck
--     code, so none of them are exposed
-- Physical Controls Locked service (siid=6)
--   piid=1 physical-controls-locked, bool, RW
--   piid=2 current-physical-control-lock mirrors piid=1, not exposed
-- Custom service (siid=5)
--   piid=10 stepless-fan-level, uint8, RW range 1..100
--   piid=2 timing, piid=4/5 swing-back flags, piid=6/7 step-move strings, and
--     piid=8/9 one-key macros are schedule and remote-button helpers
-- Custom service (siid=7): toggle actions duplicate the switch and mode writes
--
-- The angles are continuous ranges, so the capabilities carry them as strings
-- for iOS compatibility and this driver converts to a number before writing.

local FAN_SIID = 2
local POWER_PIID = 1
local FAN_LEVEL_PIID = 2
local SWING_PIID = 3
local H_ANGLE_PIID = 12
local V_ANGLE_PIID = 14
local MODE_PIID = 7
local BRIGHTNESS_PIID = 10
local ALARM_PIID = 11

local LOCK_SIID = 6
local LOCK_PIID = 1

local CUSTOM_SIID = 5
local FAN_SPEED_PIID = 10

local SENSOR_SIID = 7
local MOTOR_SPEED_PIID = 2

-- MIoT -> SmartThings
local FAN_LEVEL_TO_ST = {
    [1] = "level1",
    [2] = "level2",
    [3] = "level3",
    [4] = "level4"
}

-- SmartThings -> MIoT
local ST_TO_FAN_LEVEL = {
    level1 = 1,
    level2 = 2,
    level3 = 3,
    level4 = 4
}

local MODE_TO_ST = {
    [0] = "natural",
    [1] = "straight",
    [2] = "tempWind"
}

local ST_TO_MODE = {
    natural = 0,
    straight = 1,
    tempWind = 2
}

local SUPPORTED_OSCILLATION_MODES = {"off", "horizontal"}

local H_ANGLE_MAX = 120
local V_ANGLE_MAX = 100
local FAN_SPEED_MIN = 1
local FAN_SPEED_MAX = 100

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(hAngleCap.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function bool_to_st(value)
    return value and "on" or "off"
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = FAN_SIID, piid = POWER_PIID},
        {siid = FAN_SIID, piid = FAN_LEVEL_PIID},
        {siid = FAN_SIID, piid = SWING_PIID},
        {siid = FAN_SIID, piid = H_ANGLE_PIID},
        {siid = FAN_SIID, piid = V_ANGLE_PIID},
        {siid = FAN_SIID, piid = MODE_PIID},
        {siid = FAN_SIID, piid = BRIGHTNESS_PIID},
        {siid = FAN_SIID, piid = ALARM_PIID},
        {siid = LOCK_SIID, piid = LOCK_PIID},
        {siid = CUSTOM_SIID, piid = FAN_SPEED_PIID},
        {siid = SENSOR_SIID, piid = MOTOR_SPEED_PIID}
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
                    device:emit_event(capabilities.switch.switch(bool_to_st(value)))
                elseif piid == FAN_LEVEL_PIID then
                    local level = FAN_LEVEL_TO_ST[value]
                    if level then
                        device:emit_event(fanLevelCap.fanLevel({value = level}))
                    end
                elseif piid == SWING_PIID then
                    local mode = value and "horizontal" or "off"
                    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(mode))
                elseif piid == H_ANGLE_PIID then
                    device:emit_event(hAngleCap.horizontalAngle({value = tostring(math.floor(value))}))
                elseif piid == V_ANGLE_PIID then
                    device:emit_event(vAngleCap.verticalAngle({value = tostring(math.floor(value))}))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(fanModeCap.fanMode({value = mode}))
                    end
                elseif piid == BRIGHTNESS_PIID then
                    device:emit_event(indicatorCap.indicatorLight({value = value == 1 and "on" or "off"}))
                elseif piid == ALARM_PIID then
                    device:emit_event(buzzerCap.buzzer({value = bool_to_st(value)}))
                end
            elseif siid == LOCK_SIID and piid == LOCK_PIID then
                device:emit_event(childLockCap.childLock({value = bool_to_st(value)}))
            elseif siid == CUSTOM_SIID and piid == FAN_SPEED_PIID then
                device:emit_event(capabilities.fanSpeedPercent.percent(math.floor(value)))
            elseif siid == SENSOR_SIID and piid == MOTOR_SPEED_PIID then
                device:emit_event(motorSpeedCap.motorSpeed({value = math.floor(value), unit = "rpm"}))
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

local function set_percent_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.percent)
    if not requested then return end

    local value = math.floor(clamp(requested, FAN_SPEED_MIN, FAN_SPEED_MAX))
    local ok = pcall(miot.set, device, ip, token, CUSTOM_SIID, FAN_SPEED_PIID, value)
    if ok then
        device:emit_event(capabilities.fanSpeedPercent.percent(value))
    end
end

local function set_fan_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = command.args.fanLevel
    local value = ST_TO_FAN_LEVEL[level]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, FAN_LEVEL_PIID, value)
    if ok then
        device:emit_event(fanLevelCap.fanLevel({value = level}))
    end
end

local function set_fan_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.fanMode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, FAN_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(fanModeCap.fanMode({value = mode}))
    end
end

local function set_oscillation_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.fanOscillationMode
    local ok = pcall(miot.set, device, ip, token, FAN_SIID, SWING_PIID, requested == "horizontal")
    if ok then
        device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(requested))
    end
end

local function make_angle_handler(piid, capability, attribute, argument, maximum)
    return function(_, device, command)
        local ip, token = get_device_config(device)
        if not ip then return end

        local requested = tonumber(command.args[argument])
        if not requested then return end

        local value = math.floor(clamp(requested, 0, maximum))
        local ok = pcall(miot.set, device, ip, token, FAN_SIID, piid, value)
        if ok then
            device:emit_event(capability[attribute]({value = tostring(value)}))
        end
    end
end

local set_h_angle_handler = make_angle_handler(H_ANGLE_PIID, hAngleCap, "horizontalAngle", "horizontalAngle", H_ANGLE_MAX)
local set_v_angle_handler = make_angle_handler(V_ANGLE_PIID, vAngleCap, "verticalAngle", "verticalAngle", V_ANGLE_MAX)

local function set_indicator_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.indicatorLight
    local ok = pcall(miot.set, device, ip, token, FAN_SIID, BRIGHTNESS_PIID, requested == "on" and 1 or 0)
    if ok then
        device:emit_event(indicatorCap.indicatorLight({value = requested}))
    end
end

local function make_bool_handler(siid, piid, capability, attribute, argument)
    return function(_, device, command)
        local ip, token = get_device_config(device)
        if not ip then return end

        local requested = command.args[argument]
        local ok = pcall(miot.set, device, ip, token, siid, piid, requested == "on")
        if ok then
            device:emit_event(capability[attribute]({value = requested}))
        end
    end
end

local set_buzzer_handler = make_bool_handler(FAN_SIID, ALARM_PIID, buzzerCap, "buzzer", "buzzer")
local set_child_lock_handler = make_bool_handler(LOCK_SIID, LOCK_PIID, childLockCap, "childLock", "childLock")

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:online()
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.fanSpeedPercent.percent(1))
    device:emit_event(fanLevelCap.fanLevel({value = "level1"}))
    device:emit_event(fanModeCap.fanMode({value = "straight"}))
    device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes(SUPPORTED_OSCILLATION_MODES))
    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode("off"))
    device:emit_event(hAngleCap.horizontalAngle({value = "60"}))
    device:emit_event(vAngleCap.verticalAngle({value = "50"}))
    device:emit_event(indicatorCap.indicatorLight({value = "on"}))
    device:emit_event(buzzerCap.buzzer({value = "off"}))
    device:emit_event(childLockCap.childLock({value = "off"}))
    device:emit_event(motorSpeedCap.motorSpeed({value = 0, unit = "rpm"}))
    pcall(poll_device_status, device)
end

local function device_init(_, device)
    ensure_profile(device)
    device:online()

    -- Re-publish the oscillation list so the app keeps the options.
    device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes(SUPPORTED_OSCILLATION_MODES))

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

local driver = Driver("miot-zhimi-fan-fa2", {
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
            [capabilities.fanSpeedPercent.commands.setPercent.NAME] = set_percent_handler
        },
        [capabilities.fanOscillationMode.ID] = {
            [capabilities.fanOscillationMode.commands.setFanOscillationMode.NAME] = set_oscillation_handler
        },
        [fanLevelCap.ID] = {
            [fanLevelCap.commands.setFanLevel.NAME] = set_fan_level_handler
        },
        [fanModeCap.ID] = {
            [fanModeCap.commands.setFanMode.NAME] = set_fan_mode_handler
        },
        [hAngleCap.ID] = {
            [hAngleCap.commands.setHorizontalAngle.NAME] = set_h_angle_handler
        },
        [vAngleCap.ID] = {
            [vAngleCap.commands.setVerticalAngle.NAME] = set_v_angle_handler
        },
        [indicatorCap.ID] = {
            [indicatorCap.commands.setIndicatorLight.NAME] = set_indicator_handler
        },
        [buzzerCap.ID] = {
            [buzzerCap.commands.setBuzzer.NAME] = set_buzzer_handler
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
