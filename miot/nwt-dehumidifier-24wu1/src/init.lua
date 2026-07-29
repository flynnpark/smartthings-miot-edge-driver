-- NWT Dehumidifier 24WU1 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local modeControl = capabilities["concertmirror08464.nwtDerh24wuMode"]
local targetHumidityControl = capabilities["concertmirror08464.nwtDerh24wuTargetHumidity"]
local fanLevelControl = capabilities["concertmirror08464.nwtDerh24wuFanLevel"]
local dryClothesControl = capabilities["concertmirror08464.nwtDerh24wuDryClothes"]
local swingControl = capabilities["concertmirror08464.nwtDerh24wuSwing"]
local uvControl = capabilities["concertmirror08464.nwtDerh24wuUv"]
local indicatorLightControl = capabilities["concertmirror08464.nwtDerh24wuIndicatorLight"]
local alarmControl = capabilities["concertmirror08464.nwtDerh24wuAlarm"]
local childLockControl = capabilities["concertmirror08464.nwtDerh24wuChildLock"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "nwt-dehumidifier-24wu1"

-- MIoT model: nwt.derh.24wu1
-- specModel: nwt-24wu1
-- URN: urn:miot-spec-v2:device:dehumidifier:0000A02D:nwt-24wu1:1
--
-- Dehumidifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R: 0=noFaults, 2=E2, 3=E4, 4=E5, 5=E9, not exposed
--   piid=3 mode, uint8, RW enum: 0=auto, 1=dry, 2=circle, 3=close
--   piid=5 target-humidity, uint8, RW range 30..70 step 10, %
--   piid=7 fan-level, uint8, RW enum: 0=low, 1=medium, 2=high
-- Environment service (siid=3)
--   piid=1 relative-humidity, uint8, R, 20..90 %
-- Alarm service (siid=4)
--   piid=1 alarm, bool, RW
-- Indicator Light service (siid=5)
--   piid=1 on, bool, RW
-- Physical Control Locked service (siid=6)
--   piid=1 physical-controls-locked, bool, RW
-- syn service (siid=7)
--   piid=1 dry-clothes, uint8, RW enum: 0=automatic, 1=weak, 2=strong, 3=close
--   piid=2 swing, uint8, RW enum: 0=automatic, 1=leftRight, 2=upDown, 3=cancel
--   piid=3 uv, uint8, RW enum: 0=automatic, 1=weak, 2=strong, 3=close
--   piid=5, piid=6 read-only diagnostics, not exposed

local DEHUMIDIFIER_SIID = 2
local POWER_PIID = 1
local MODE_PIID = 3
local TARGET_HUMIDITY_PIID = 5
local FAN_LEVEL_PIID = 7

local ENVIRONMENT_SIID = 3
local HUMIDITY_PIID = 1

local ALARM_SIID = 4
local ALARM_PIID = 1

local INDICATOR_SIID = 5
local INDICATOR_ON_PIID = 1

local CHILD_LOCK_SIID = 6
local CHILD_LOCK_PIID = 1

local SYN_SIID = 7
local DRY_CLOTHES_PIID = 1
local SWING_PIID = 2
local UV_PIID = 3

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [0] = "auto",
    [1] = "dry",
    [2] = "circle",
    [3] = "close"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    auto = 0,
    dry = 1,
    circle = 2,
    close = 3
}

local FAN_LEVEL_TO_ST = {
    [0] = "low",
    [1] = "medium",
    [2] = "high"
}

local ST_TO_FAN_LEVEL = {
    low = 0,
    medium = 1,
    high = 2
}

local DRY_CLOTHES_TO_ST = {
    [0] = "automatic",
    [1] = "weak",
    [2] = "strong",
    [3] = "close"
}

local ST_TO_DRY_CLOTHES = {
    automatic = 0,
    weak = 1,
    strong = 2,
    close = 3
}

local SWING_TO_ST = {
    [0] = "automatic",
    [1] = "leftRight",
    [2] = "upDown",
    [3] = "cancel"
}

local ST_TO_SWING = {
    automatic = 0,
    leftRight = 1,
    upDown = 2,
    cancel = 3
}

local UV_TO_ST = {
    [0] = "automatic",
    [1] = "weak",
    [2] = "strong",
    [3] = "close"
}

local ST_TO_UV = {
    automatic = 0,
    weak = 1,
    strong = 2,
    close = 3
}

local TARGET_HUMIDITY_MIN = 30
local TARGET_HUMIDITY_MAX = 70
local TARGET_HUMIDITY_STEP = 10

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function bool_to_st(value)
    return value and "on" or "off"
end

-- The device uses a 30..70 step 10 range while SmartThings uses "h<value>"
-- string enum values, so both directions convert here.
local function humidity_to_st(value)
    if type(value) ~= "number" then
        return nil
    end
    if value < TARGET_HUMIDITY_MIN or value > TARGET_HUMIDITY_MAX then
        return nil
    end
    if value % TARGET_HUMIDITY_STEP ~= 0 then
        return nil
    end
    return "h" .. tostring(value)
end

local function st_to_humidity(value)
    if type(value) ~= "string" then
        return nil
    end
    local number = tonumber(value:match("^h(%d+)$"))
    if not number then
        return nil
    end
    if number < TARGET_HUMIDITY_MIN or number > TARGET_HUMIDITY_MAX then
        return nil
    end
    return number
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = DEHUMIDIFIER_SIID, piid = POWER_PIID},
        {siid = DEHUMIDIFIER_SIID, piid = MODE_PIID},
        {siid = DEHUMIDIFIER_SIID, piid = TARGET_HUMIDITY_PIID},
        {siid = DEHUMIDIFIER_SIID, piid = FAN_LEVEL_PIID},
        {siid = ENVIRONMENT_SIID, piid = HUMIDITY_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_ON_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = SYN_SIID, piid = DRY_CLOTHES_PIID},
        {siid = SYN_SIID, piid = SWING_PIID},
        {siid = SYN_SIID, piid = UV_PIID}
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

            if siid == DEHUMIDIFIER_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(modeControl.mode({value = mode}))
                    end
                elseif piid == TARGET_HUMIDITY_PIID then
                    local target = humidity_to_st(value)
                    if target then
                        device:emit_event(targetHumidityControl.targetHumidity({value = target}))
                    end
                elseif piid == FAN_LEVEL_PIID then
                    local level = FAN_LEVEL_TO_ST[value]
                    if level then
                        device:emit_event(fanLevelControl.fanLevel({value = level}))
                    end
                end
            elseif siid == ENVIRONMENT_SIID and piid == HUMIDITY_PIID then
                device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(alarmControl.alarm({value = bool_to_st(value)}))
            elseif siid == INDICATOR_SIID and piid == INDICATOR_ON_PIID then
                device:emit_event(indicatorLightControl.indicatorLight({value = bool_to_st(value)}))
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(childLockControl.childLock({value = bool_to_st(value)}))
            elseif siid == SYN_SIID then
                if piid == DRY_CLOTHES_PIID then
                    local dry = DRY_CLOTHES_TO_ST[value]
                    if dry then
                        device:emit_event(dryClothesControl.dryClothes({value = dry}))
                    end
                elseif piid == SWING_PIID then
                    local swing = SWING_TO_ST[value]
                    if swing then
                        device:emit_event(swingControl.swing({value = swing}))
                    end
                elseif piid == UV_PIID then
                    local uv = UV_TO_ST[value]
                    if uv then
                        device:emit_event(uvControl.uv({value = uv}))
                    end
                end
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

    local ok = pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, POWER_PIID, true)
    local ok = pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(modeControl.mode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_target_humidity_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local target = command.args.targetHumidity
    local value = st_to_humidity(target)
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, TARGET_HUMIDITY_PIID, value)
    if ok then
        device:emit_event(targetHumidityControl.targetHumidity({value = target}))
    end
end

local function set_fan_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = command.args.fanLevel
    local value = ST_TO_FAN_LEVEL[level]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, DEHUMIDIFIER_SIID, FAN_LEVEL_PIID, value)
    if ok then
        device:emit_event(fanLevelControl.fanLevel({value = level}))
    end
end

local function set_dry_clothes_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local dry = command.args.dryClothes
    local value = ST_TO_DRY_CLOTHES[dry]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, SYN_SIID, DRY_CLOTHES_PIID, value)
    if ok then
        device:emit_event(dryClothesControl.dryClothes({value = dry}))
    end
end

local function set_swing_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local swing = command.args.swing
    local value = ST_TO_SWING[swing]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, SYN_SIID, SWING_PIID, value)
    if ok then
        device:emit_event(swingControl.swing({value = swing}))
    end
end

local function set_uv_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local uv = command.args.uv
    local value = ST_TO_UV[uv]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, SYN_SIID, UV_PIID, value)
    if ok then
        device:emit_event(uvControl.uv({value = uv}))
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

local function set_alarm_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local alarm = command.args.alarm
    local ok = pcall(miot.set, device, ip, token, ALARM_SIID, ALARM_PIID, alarm == "on")
    if ok then
        device:emit_event(alarmControl.alarm({value = alarm}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    local ok = pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, child_lock == "on")
    if ok then
        device:emit_event(childLockControl.childLock({value = child_lock}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(uvControl.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
    device:emit_event(modeControl.mode({value = "auto"}))
    device:emit_event(targetHumidityControl.targetHumidity({value = "h50"}))
    device:emit_event(fanLevelControl.fanLevel({value = "low"}))
    device:emit_event(dryClothesControl.dryClothes({value = "close"}))
    device:emit_event(swingControl.swing({value = "cancel"}))
    device:emit_event(uvControl.uv({value = "close"}))
    device:emit_event(indicatorLightControl.indicatorLight({value = "on"}))
    device:emit_event(alarmControl.alarm({value = "off"}))
    device:emit_event(childLockControl.childLock({value = "off"}))
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

local driver = Driver("miot-nwt-dehumidifier-24wu1", {
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
        [modeControl.ID] = {
            [modeControl.commands.setMode.NAME] = set_mode_handler
        },
        [targetHumidityControl.ID] = {
            [targetHumidityControl.commands.setTargetHumidity.NAME] = set_target_humidity_handler
        },
        [fanLevelControl.ID] = {
            [fanLevelControl.commands.setFanLevel.NAME] = set_fan_level_handler
        },
        [dryClothesControl.ID] = {
            [dryClothesControl.commands.setDryClothes.NAME] = set_dry_clothes_handler
        },
        [swingControl.ID] = {
            [swingControl.commands.setSwing.NAME] = set_swing_handler
        },
        [uvControl.ID] = {
            [uvControl.commands.setUv.NAME] = set_uv_handler
        },
        [indicatorLightControl.ID] = {
            [indicatorLightControl.commands.setIndicatorLight.NAME] = set_indicator_light_handler
        },
        [alarmControl.ID] = {
            [alarmControl.commands.setAlarm.NAME] = set_alarm_handler
        },
        [childLockControl.ID] = {
            [childLockControl.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
