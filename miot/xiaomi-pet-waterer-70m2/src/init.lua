-- Xiaomi Pet Waterer 70M2 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local modeControl = capabilities["concertmirror08464.xiaomiPetWater70m2Mode"]
local intervalControl = capabilities["concertmirror08464.xiaomiPetWater70m2Interval"]
local operatingStatus = capabilities["concertmirror08464.xiaomiPetWater70m2Status"]
local waterShortageStatus = capabilities["concertmirror08464.xiaomiPetWater70m2WaterShortage"]
local filterLifeStatus = capabilities["concertmirror08464.xiaomiPetWater70m2FilterLife"]
local pumpBlockStatus = capabilities["concertmirror08464.xiaomiPetWater70m2PumpBlock"]
local childLockControl = capabilities["concertmirror08464.xiaomiPetWater70m2ChildLock"]
local noDisturbControl = capabilities["concertmirror08464.xiaomiPetWater70m2NoDisturb"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "xiaomi-pet-waterer-70m2"

-- MIoT model: xiaomi.pet_waterer.70m2
-- specModel: xiaomi-70m2
-- URN: urn:miot-spec-v2:device:pet-drinking-fountain:0000A067:xiaomi-70m2:2
--
-- Pet Drinking Fountain service (siid=2)
--   piid=1 fault, uint8, R: 0=noFaults, not exposed
--   piid=3 status, uint8, R enum: 1=waterless, 2=watering
--   piid=4 mode, uint8, RW enum: 0=auto, 1=interval, 2=constant
--   piid=7 out-water-interval, uint8, RW range 15..120 step 15, not exposed
--   piid=10 water-shortage-status, bool, R: true=shortage, false=normal
--   piid=11 out-water-interval, uint8, RW range 10..120 step 5, minutes
--   This exact spec has no whole-device power property, so no switch is exposed.
-- Filter service (siid=3)
--   piid=1 filter-life-level, uint8, R, 0..100 %
--   piid=2 filter-left-time, uint16, R, days, not exposed
--   aiid=1 reset-filter-life, action, not exposed
-- Physical Control Locked service (siid=4)
--   piid=1 physical-controls-locked, bool, RW
-- Battery service (siid=5)
--   piid=1 battery-level, uint8, R, 0..100 %
--   piid=2 charging-state, uint8, R, not exposed
-- No Disturb service (siid=6)
--   piid=1 no-disturb, bool, RW
-- pet-waterer-costom service (siid=9)
--   piid=12 pump-block, bool, R: true=blocked, false=normal
--   other properties are diagnostics or factory values, not exposed

local FOUNTAIN_SIID = 2
local STATUS_PIID = 3
local MODE_PIID = 4
local WATER_SHORTAGE_PIID = 10
local OUT_WATER_INTERVAL_PIID = 11

local FILTER_SIID = 3
local FILTER_LIFE_PIID = 1

local CHILD_LOCK_SIID = 4
local CHILD_LOCK_PIID = 1

local BATTERY_SIID = 5
local BATTERY_LEVEL_PIID = 1

local NO_DISTURB_SIID = 6
local NO_DISTURB_PIID = 1

local CUSTOM_SIID = 9
local PUMP_BLOCK_PIID = 12

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [0] = "auto",
    [1] = "interval",
    [2] = "constant"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    auto = 0,
    interval = 1,
    constant = 2
}

local STATUS_TO_ST = {
    [1] = "waterless",
    [2] = "watering"
}

local INTERVAL_MIN = 10
local INTERVAL_MAX = 120
local INTERVAL_STEP = 5

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
        {siid = FOUNTAIN_SIID, piid = STATUS_PIID},
        {siid = FOUNTAIN_SIID, piid = MODE_PIID},
        {siid = FOUNTAIN_SIID, piid = WATER_SHORTAGE_PIID},
        {siid = FOUNTAIN_SIID, piid = OUT_WATER_INTERVAL_PIID},
        {siid = FILTER_SIID, piid = FILTER_LIFE_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = BATTERY_SIID, piid = BATTERY_LEVEL_PIID},
        {siid = NO_DISTURB_SIID, piid = NO_DISTURB_PIID},
        {siid = CUSTOM_SIID, piid = PUMP_BLOCK_PIID}
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

            if siid == FOUNTAIN_SIID then
                if piid == STATUS_PIID then
                    local status = STATUS_TO_ST[value]
                    if status then
                        device:emit_event(operatingStatus.operatingStatus({value = status}))
                    end
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(modeControl.mode({value = mode}))
                    end
                elseif piid == WATER_SHORTAGE_PIID then
                    device:emit_event(waterShortageStatus.waterShortage({value = value and "shortage" or "normal"}))
                elseif piid == OUT_WATER_INTERVAL_PIID then
                    device:emit_event(intervalControl.outWaterInterval({value = value, unit = "min"}))
                end
            elseif siid == FILTER_SIID and piid == FILTER_LIFE_PIID then
                device:emit_event(filterLifeStatus.filterLifeLevel({value = value, unit = "%"}))
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(childLockControl.childLock({value = bool_to_st(value)}))
            elseif siid == BATTERY_SIID and piid == BATTERY_LEVEL_PIID then
                device:emit_event(capabilities.battery.battery(value))
            elseif siid == NO_DISTURB_SIID and piid == NO_DISTURB_PIID then
                device:emit_event(noDisturbControl.noDisturb({value = bool_to_st(value)}))
            elseif siid == CUSTOM_SIID and piid == PUMP_BLOCK_PIID then
                device:emit_event(pumpBlockStatus.pumpBlock({value = value and "blocked" or "normal"}))
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

local function set_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, FOUNTAIN_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(modeControl.mode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_out_water_interval_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.interval)
    if not requested then return end
    if requested < INTERVAL_MIN or requested > INTERVAL_MAX then return end

    -- The device accepts 10..120 in steps of 5, so snap the slider value.
    local value = math.floor(requested / INTERVAL_STEP + 0.5) * INTERVAL_STEP
    if value < INTERVAL_MIN then value = INTERVAL_MIN end
    if value > INTERVAL_MAX then value = INTERVAL_MAX end

    local ok = pcall(miot.set, device, ip, token, FOUNTAIN_SIID, OUT_WATER_INTERVAL_PIID, value)
    if ok then
        device:emit_event(intervalControl.outWaterInterval({value = value, unit = "min"}))
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

local function set_no_disturb_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local no_disturb = command.args.noDisturb
    local ok = pcall(miot.set, device, ip, token, NO_DISTURB_SIID, NO_DISTURB_PIID, no_disturb == "on")
    if ok then
        device:emit_event(noDisturbControl.noDisturb({value = no_disturb}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(pumpBlockStatus.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.battery.battery(100))
    device:emit_event(modeControl.mode({value = "auto"}))
    device:emit_event(intervalControl.outWaterInterval({value = 30, unit = "min"}))
    device:emit_event(operatingStatus.operatingStatus({value = "watering"}))
    device:emit_event(waterShortageStatus.waterShortage({value = "normal"}))
    device:emit_event(filterLifeStatus.filterLifeLevel({value = 100, unit = "%"}))
    device:emit_event(pumpBlockStatus.pumpBlock({value = "normal"}))
    device:emit_event(childLockControl.childLock({value = "off"}))
    device:emit_event(noDisturbControl.noDisturb({value = "off"}))
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

local driver = Driver("miot-xiaomi-pet-waterer-70m2", {
    discovery = discovery.handle_discovery,
    lifecycle_handlers = {
        added = device_added,
        init = device_init,
        removed = device_removed,
        infoChanged = device_info_changed
    },
    capability_handlers = {
        [modeControl.ID] = {
            [modeControl.commands.setMode.NAME] = set_mode_handler
        },
        [intervalControl.ID] = {
            [intervalControl.commands.setOutWaterInterval.NAME] = set_out_water_interval_handler
        },
        [childLockControl.ID] = {
            [childLockControl.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [noDisturbControl.ID] = {
            [noDisturbControl.commands.setNoDisturb.NAME] = set_no_disturb_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
