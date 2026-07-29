-- Xiaomi Curtain ACN009 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local speedControl = capabilities["concertmirror08464.xiaomiCurtainAcn009Speed"]
local reverseControl = capabilities["concertmirror08464.xiaomiCurtainAcn009Reverse"]
local manualDrawControl = capabilities["concertmirror08464.xiaomiCurtainAcn009ManualDraw"]
local indicatorLightControl = capabilities["concertmirror08464.xiaomiCurtainAcn009Indicator"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "xiaomi-curtain-acn009"

-- MIoT model: xiaomi.curtain.acn009
-- specModel: xiaomi-acn009
-- URN: urn:miot-spec-v2:device:curtain:0000A00C:xiaomi-acn009:1
--
-- Curtain service (siid=2)
--   piid=1 fault, uint8, R: 0=noFaults, not exposed
--   piid=2 motor-control, uint8, W enum: 0=pause, 1=open, 2=close, 3=toggle
--   piid=3 status, uint8, R enum: 0=stop, 1=opening, 2=closing
--   piid=4 current-position, uint8, R, 0..100 %
--   piid=5 target-position, uint8, RW, 0..100 %
--   piid=6 motor-reverse, bool, RW
--   piid=8 speed-level, uint8, RW enum: 0=low, 1=medium, 2=high
--   piid=9 manual-draw, uint8, RW enum: 0=enable, 1=disable
--   piid=7 wake-up-mode, piid=10 travel-point, piid=11 journey time: not exposed
-- Indicator Light service (siid=5)
--   piid=1 on, bool, RW
-- Remote Control Management (siid=3), Identify (siid=4), and
--   custom-function (siid=6): pairing, aging test, and rail diagnostics,
--   not exposed

local CURTAIN_SIID = 2
local MOTOR_CONTROL_PIID = 2
local STATUS_PIID = 3
local CURRENT_POSITION_PIID = 4
local TARGET_POSITION_PIID = 5
local MOTOR_REVERSE_PIID = 6
local SPEED_LEVEL_PIID = 8
local MANUAL_DRAW_PIID = 9

local INDICATOR_SIID = 5
local INDICATOR_ON_PIID = 1

-- SmartThings -> MIoT motor control
local MOTOR_PAUSE = 0
local MOTOR_OPEN = 1
local MOTOR_CLOSE = 2

-- MIoT -> SmartThings
local STATUS_TO_ST = {
    [0] = "partially open",
    [1] = "opening",
    [2] = "closing"
}

local SPEED_TO_ST = {
    [0] = "low",
    [1] = "medium",
    [2] = "high"
}

-- SmartThings -> MIoT
local ST_TO_SPEED = {
    low = 0,
    medium = 1,
    high = 2
}

local MANUAL_DRAW_TO_ST = {
    [0] = "enable",
    [1] = "disable"
}

local ST_TO_MANUAL_DRAW = {
    enable = 0,
    disable = 1
}

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

-- The device reports motion state and position separately, so a stopped
-- curtain resolves to open, closed, or partially open from the position.
local function emit_shade_state(device, status, position)
    if status == 1 then
        device:emit_event(capabilities.windowShade.windowShade.opening())
        return
    end
    if status == 2 then
        device:emit_event(capabilities.windowShade.windowShade.closing())
        return
    end
    if position == nil then
        return
    end
    if position >= 99 then
        device:emit_event(capabilities.windowShade.windowShade.open())
    elseif position <= 1 then
        device:emit_event(capabilities.windowShade.windowShade.closed())
    else
        device:emit_event(capabilities.windowShade.windowShade.partially_open())
    end
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = CURTAIN_SIID, piid = STATUS_PIID},
        {siid = CURTAIN_SIID, piid = CURRENT_POSITION_PIID},
        {siid = CURTAIN_SIID, piid = MOTOR_REVERSE_PIID},
        {siid = CURTAIN_SIID, piid = SPEED_LEVEL_PIID},
        {siid = CURTAIN_SIID, piid = MANUAL_DRAW_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_ON_PIID}
    }

    local ok, response = pcall(miot.gets, device, ip, token, properties)
    if not ok or not response or not response.result then
        return
    end

    local status = nil
    local position = nil

    for _, result in ipairs(response.result) do
        if result.code == 0 then
            local siid = result.siid
            local piid = result.piid
            local value = result.value

            if siid == CURTAIN_SIID then
                if piid == STATUS_PIID then
                    status = value
                elseif piid == CURRENT_POSITION_PIID then
                    position = value
                    device:emit_event(capabilities.windowShadeLevel.shadeLevel(value))
                elseif piid == MOTOR_REVERSE_PIID then
                    device:emit_event(reverseControl.motorReverse({value = value and "on" or "off"}))
                elseif piid == SPEED_LEVEL_PIID then
                    local speed = SPEED_TO_ST[value]
                    if speed then
                        device:emit_event(speedControl.speedLevel({value = speed}))
                    end
                elseif piid == MANUAL_DRAW_PIID then
                    local manual = MANUAL_DRAW_TO_ST[value]
                    if manual then
                        device:emit_event(manualDrawControl.manualDraw({value = manual}))
                    end
                end
            elseif siid == INDICATOR_SIID and piid == INDICATOR_ON_PIID then
                device:emit_event(indicatorLightControl.indicatorLight({value = value and "on" or "off"}))
            end
        end
    end

    emit_shade_state(device, status, position)
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

local function open_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.set, device, ip, token, CURTAIN_SIID, MOTOR_CONTROL_PIID, MOTOR_OPEN)
    if ok then
        device:emit_event(capabilities.windowShade.windowShade.opening())
        device.thread:call_with_delay(3, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function close_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.set, device, ip, token, CURTAIN_SIID, MOTOR_CONTROL_PIID, MOTOR_CLOSE)
    if ok then
        device:emit_event(capabilities.windowShade.windowShade.closing())
        device.thread:call_with_delay(3, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function pause_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.set, device, ip, token, CURTAIN_SIID, MOTOR_CONTROL_PIID, MOTOR_PAUSE)
    if ok then
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_shade_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = tonumber(command.args.shadeLevel)
    if not level then return end
    if level < 0 then level = 0 end
    if level > 100 then level = 100 end

    local value = math.floor(level)
    local ok = pcall(miot.set, device, ip, token, CURTAIN_SIID, TARGET_POSITION_PIID, value)
    if ok then
        device:emit_event(capabilities.windowShadeLevel.shadeLevel(value))
        device.thread:call_with_delay(3, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_speed_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local speed = command.args.speedLevel
    local value = ST_TO_SPEED[speed]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, CURTAIN_SIID, SPEED_LEVEL_PIID, value)
    if ok then
        device:emit_event(speedControl.speedLevel({value = speed}))
    end
end

local function set_motor_reverse_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local reverse = command.args.motorReverse
    local ok = pcall(miot.set, device, ip, token, CURTAIN_SIID, MOTOR_REVERSE_PIID, reverse == "on")
    if ok then
        device:emit_event(reverseControl.motorReverse({value = reverse}))
    end
end

local function set_manual_draw_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local manual = command.args.manualDraw
    local value = ST_TO_MANUAL_DRAW[manual]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, CURTAIN_SIID, MANUAL_DRAW_PIID, value)
    if ok then
        device:emit_event(manualDrawControl.manualDraw({value = manual}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator = command.args.indicatorLight
    local ok = pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_ON_PIID, indicator == "on")
    if ok then
        device:emit_event(indicatorLightControl.indicatorLight({value = indicator}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(speedControl.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.windowShade.windowShade.closed())
    device:emit_event(capabilities.windowShadeLevel.shadeLevel(0))
    device:emit_event(speedControl.speedLevel({value = "medium"}))
    device:emit_event(reverseControl.motorReverse({value = "off"}))
    device:emit_event(manualDrawControl.manualDraw({value = "enable"}))
    device:emit_event(indicatorLightControl.indicatorLight({value = "on"}))
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

local driver = Driver("miot-xiaomi-curtain-acn009", {
    discovery = discovery.handle_discovery,
    lifecycle_handlers = {
        added = device_added,
        init = device_init,
        removed = device_removed,
        infoChanged = device_info_changed
    },
    capability_handlers = {
        [capabilities.windowShade.ID] = {
            [capabilities.windowShade.commands.open.NAME] = open_handler,
            [capabilities.windowShade.commands.close.NAME] = close_handler,
            [capabilities.windowShade.commands.pause.NAME] = pause_handler
        },
        [capabilities.windowShadeLevel.ID] = {
            [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = set_shade_level_handler
        },
        [speedControl.ID] = {
            [speedControl.commands.setSpeedLevel.NAME] = set_speed_level_handler
        },
        [reverseControl.ID] = {
            [reverseControl.commands.setMotorReverse.NAME] = set_motor_reverse_handler
        },
        [manualDrawControl.ID] = {
            [manualDrawControl.commands.setManualDraw.NAME] = set_manual_draw_handler
        },
        [indicatorLightControl.ID] = {
            [indicatorLightControl.commands.setIndicatorLight.NAME] = set_indicator_light_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
