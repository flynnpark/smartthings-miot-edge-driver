-- Xiaomi Hood YMV5 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local fanLevelControl = capabilities["concertmirror08464.xiaomiHoodYmv5FanLevel"]
local lightControl = capabilities["concertmirror08464.xiaomiHoodYmv5Light"]
local offDelayControl = capabilities["concertmirror08464.xiaomiHoodYmv5OffDelay"]
local countdownControl = capabilities["concertmirror08464.xiaomiHoodYmv5Countdown"]
local cleanRemindControl = capabilities["concertmirror08464.xiaomiHoodYmv5CleanRemind"]
local stoveLinkStatus = capabilities["concertmirror08464.xiaomiHoodYmv5StoveLink"]
local dryStatus = capabilities["concertmirror08464.xiaomiHoodYmv5DryStatus"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "xiaomi-hood-ymv5"

-- MIoT model: xiaomi.hood.ymv5
-- specModel: xiaomi-ymv5
-- URN: urn:miot-spec-v2:device:hood:0000A01B:xiaomi-ymv5:3
--
-- Hood service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint32, R, raw code, not exposed
--   piid=3 power-off-delay, bool, RW
--   piid=5 countdown-time, uint16, RW range 0..420 seconds
--   piid=6 stove-link-status, uint8, R enum: 0=unbound, 1=unlinked, 2=linked
--   piid=13 clean-remind-on, bool, RW
--   piid=4 delay time, piid=7..12, piid=14..16: holiday mode, light linkage,
--     clean remind hours, cruise, and gestures, not exposed
-- Kitchen Stove service (siid=3): burner status and bind actions, not exposed
-- Light service (siid=4)
--   piid=1 on, bool, RW
--   aiid=1 toggle, action, not exposed
-- Fan Control service (siid=5)
--   piid=1 fan-level, uint8, RW enum: 0=low, 1=high, 2=stirFry
-- Battery service (siid=6): remote battery low/normal flag, not exposed
-- Hood Smart Dry Wash service (siid=7)
--   piid=2 dry-cleaning-status, uint8, R enum: 0=notStarted, 1=preDry,
--     2=dryCleaning, 3=dryCompleted
--   piid=1, piid=3, piid=4 and the dry actions are scheduling and maintenance
--     values, not exposed

local HOOD_SIID = 2
local POWER_PIID = 1
local POWER_OFF_DELAY_PIID = 3
local COUNTDOWN_PIID = 5
local STOVE_LINK_PIID = 6
local CLEAN_REMIND_PIID = 13

local LIGHT_SIID = 4
local LIGHT_ON_PIID = 1

local FAN_SIID = 5
local FAN_LEVEL_PIID = 1

local DRY_SIID = 7
local DRY_STATUS_PIID = 2

-- MIoT -> SmartThings
local FAN_LEVEL_TO_ST = {
    [0] = "low",
    [1] = "high",
    [2] = "stirFry"
}

-- SmartThings -> MIoT
local ST_TO_FAN_LEVEL = {
    low = 0,
    high = 1,
    stirFry = 2
}

local STOVE_LINK_TO_ST = {
    [0] = "unbound",
    [1] = "unlinked",
    [2] = "linked"
}

local DRY_STATUS_TO_ST = {
    [0] = "notStarted",
    [1] = "preDry",
    [2] = "dryCleaning",
    [3] = "dryCompleted"
}

local COUNTDOWN_MIN = 0
local COUNTDOWN_MAX = 420

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

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = HOOD_SIID, piid = POWER_PIID},
        {siid = HOOD_SIID, piid = POWER_OFF_DELAY_PIID},
        {siid = HOOD_SIID, piid = COUNTDOWN_PIID},
        {siid = HOOD_SIID, piid = STOVE_LINK_PIID},
        {siid = HOOD_SIID, piid = CLEAN_REMIND_PIID},
        {siid = LIGHT_SIID, piid = LIGHT_ON_PIID},
        {siid = FAN_SIID, piid = FAN_LEVEL_PIID},
        {siid = DRY_SIID, piid = DRY_STATUS_PIID}
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

            if siid == HOOD_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == POWER_OFF_DELAY_PIID then
                    device:emit_event(offDelayControl.powerOffDelay({value = bool_to_st(value)}))
                elseif piid == COUNTDOWN_PIID then
                    device:emit_event(countdownControl.countdownTime({value = value, unit = "s"}))
                elseif piid == STOVE_LINK_PIID then
                    local link = STOVE_LINK_TO_ST[value]
                    if link then
                        device:emit_event(stoveLinkStatus.stoveLinkStatus({value = link}))
                    end
                elseif piid == CLEAN_REMIND_PIID then
                    device:emit_event(cleanRemindControl.cleanRemind({value = bool_to_st(value)}))
                end
            elseif siid == LIGHT_SIID and piid == LIGHT_ON_PIID then
                device:emit_event(lightControl.light({value = bool_to_st(value)}))
            elseif siid == FAN_SIID and piid == FAN_LEVEL_PIID then
                local level = FAN_LEVEL_TO_ST[value]
                if level then
                    device:emit_event(fanLevelControl.fanLevel({value = level}))
                end
            elseif siid == DRY_SIID and piid == DRY_STATUS_PIID then
                local status = DRY_STATUS_TO_ST[value]
                if status then
                    device:emit_event(dryStatus.dryCleaningStatus({value = status}))
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

    local ok = pcall(miot.set, device, ip, token, HOOD_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, HOOD_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_fan_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = command.args.fanLevel
    local value = ST_TO_FAN_LEVEL[level]
    if value == nil then return end

    pcall(miot.set, device, ip, token, HOOD_SIID, POWER_PIID, true)
    local ok = pcall(miot.set, device, ip, token, FAN_SIID, FAN_LEVEL_PIID, value)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(fanLevelControl.fanLevel({value = level}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local light = command.args.light
    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_ON_PIID, light == "on")
    if ok then
        device:emit_event(lightControl.light({value = light}))
    end
end

local function set_power_off_delay_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local delay = command.args.powerOffDelay
    local ok = pcall(miot.set, device, ip, token, HOOD_SIID, POWER_OFF_DELAY_PIID, delay == "on")
    if ok then
        device:emit_event(offDelayControl.powerOffDelay({value = delay}))
    end
end

local function set_countdown_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.seconds)
    if not requested then return end
    if requested < COUNTDOWN_MIN or requested > COUNTDOWN_MAX then return end

    local value = math.floor(requested)
    local ok = pcall(miot.set, device, ip, token, HOOD_SIID, COUNTDOWN_PIID, value)
    if ok then
        device:emit_event(countdownControl.countdownTime({value = value, unit = "s"}))
    end
end

local function set_clean_remind_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local remind = command.args.cleanRemind
    local ok = pcall(miot.set, device, ip, token, HOOD_SIID, CLEAN_REMIND_PIID, remind == "on")
    if ok then
        device:emit_event(cleanRemindControl.cleanRemind({value = remind}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(fanLevelControl.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(fanLevelControl.fanLevel({value = "low"}))
    device:emit_event(lightControl.light({value = "off"}))
    device:emit_event(offDelayControl.powerOffDelay({value = "off"}))
    device:emit_event(countdownControl.countdownTime({value = 0, unit = "s"}))
    device:emit_event(cleanRemindControl.cleanRemind({value = "on"}))
    device:emit_event(stoveLinkStatus.stoveLinkStatus({value = "unbound"}))
    device:emit_event(dryStatus.dryCleaningStatus({value = "notStarted"}))
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

local driver = Driver("miot-xiaomi-hood-ymv5", {
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
        [fanLevelControl.ID] = {
            [fanLevelControl.commands.setFanLevel.NAME] = set_fan_level_handler
        },
        [lightControl.ID] = {
            [lightControl.commands.setLight.NAME] = set_light_handler
        },
        [offDelayControl.ID] = {
            [offDelayControl.commands.setPowerOffDelay.NAME] = set_power_off_delay_handler
        },
        [countdownControl.ID] = {
            [countdownControl.commands.setCountdownTime.NAME] = set_countdown_handler
        },
        [cleanRemindControl.ID] = {
            [cleanRemindControl.commands.setCleanRemind.NAME] = set_clean_remind_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
