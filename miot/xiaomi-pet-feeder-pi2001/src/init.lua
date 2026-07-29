-- Xiaomi Pet Feeder PI2001 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local measureControl = capabilities["concertmirror08464.xiaomiFeederPi2001Measure"]
local foodOutControl = capabilities["concertmirror08464.xiaomiFeederPi2001FoodOut"]
local operatingStatus = capabilities["concertmirror08464.xiaomiFeederPi2001Status"]
local foodLeftStatus = capabilities["concertmirror08464.xiaomiFeederPi2001FoodLeft"]
local foodStuckStatus = capabilities["concertmirror08464.xiaomiFeederPi2001FoodStuck"]
local desiccantStatus = capabilities["concertmirror08464.xiaomiFeederPi2001Desiccant"]
local childLockControl = capabilities["concertmirror08464.xiaomiFeederPi2001ChildLock"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "xiaomi-pet-feeder-pi2001"

-- MIoT model: xiaomi.feeder.pi2001
-- specModel: xiaomi-pi2001
-- URN: urn:miot-spec-v2:device:pet-feeder:0000A06C:xiaomi-pi2001:3
--
-- Pet Feeder service (siid=2)
--   piid=1 fault, uint8, R: 0=noFaults, 1=faults, not exposed
--   piid=6 pet-food-left-level, uint8, R enum: 0=normal, 1=low
--   piid=7 target-feeding-measure, uint8, RW range 0..150 g
--   piid=10 food-stuck-status, uint8, R enum: 0=normal, 1=abnormal
--   piid=26 status, uint8, R enum: 0=idle, 1=busy
--   aiid=1 pet-food-out, action: dispense the configured measure
--   aiid=2 weigh-manual-calibrate, action, not exposed
-- Physical Control Locked service (siid=3)
--   piid=1 physical-controls-locked, bool, RW
-- Battery service (siid=4)
--   piid=1 battery-level, uint8, R, %
-- Desiccant service (siid=6)
--   piid=1 desiccant-left-level, uint8, R, 0..100 %
--   piid=2 desiccant-left-time, uint16, R, not exposed
--   aiid=1 reset-desiccant-life, action, not exposed
-- pet-feeder-costom service (siid=5): schedule, display, and diagnostics, not exposed

local FEEDER_SIID = 2
local FOOD_LEFT_PIID = 6
local TARGET_MEASURE_PIID = 7
local FOOD_STUCK_PIID = 10
local STATUS_PIID = 26
local FOOD_OUT_AIID = 1

local CHILD_LOCK_SIID = 3
local CHILD_LOCK_PIID = 1

local BATTERY_SIID = 4
local BATTERY_LEVEL_PIID = 1

local DESICCANT_SIID = 6
local DESICCANT_LEFT_PIID = 1

-- MIoT -> SmartThings
local FOOD_LEFT_TO_ST = {
    [0] = "normal",
    [1] = "low"
}

local FOOD_STUCK_TO_ST = {
    [0] = "normal",
    [1] = "abnormal"
}

local STATUS_TO_ST = {
    [0] = "idle",
    [1] = "busy"
}

local MEASURE_MIN = 0
local MEASURE_MAX = 150

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

    local properties = {
        {siid = FEEDER_SIID, piid = FOOD_LEFT_PIID},
        {siid = FEEDER_SIID, piid = TARGET_MEASURE_PIID},
        {siid = FEEDER_SIID, piid = FOOD_STUCK_PIID},
        {siid = FEEDER_SIID, piid = STATUS_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = BATTERY_SIID, piid = BATTERY_LEVEL_PIID},
        {siid = DESICCANT_SIID, piid = DESICCANT_LEFT_PIID}
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

            if siid == FEEDER_SIID then
                if piid == FOOD_LEFT_PIID then
                    local level = FOOD_LEFT_TO_ST[value]
                    if level then
                        device:emit_event(foodLeftStatus.foodLeftLevel({value = level}))
                    end
                elseif piid == TARGET_MEASURE_PIID then
                    device:emit_event(measureControl.targetFeedingMeasure({value = value, unit = "g"}))
                elseif piid == FOOD_STUCK_PIID then
                    local stuck = FOOD_STUCK_TO_ST[value]
                    if stuck then
                        device:emit_event(foodStuckStatus.foodStuckStatus({value = stuck}))
                    end
                elseif piid == STATUS_PIID then
                    local status = STATUS_TO_ST[value]
                    if status then
                        device:emit_event(operatingStatus.operatingStatus({value = status}))
                    end
                end
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(childLockControl.childLock({value = value and "on" or "off"}))
            elseif siid == BATTERY_SIID and piid == BATTERY_LEVEL_PIID then
                device:emit_event(capabilities.battery.battery(value))
            elseif siid == DESICCANT_SIID and piid == DESICCANT_LEFT_PIID then
                device:emit_event(desiccantStatus.desiccantLeftLevel({value = value, unit = "%"}))
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

local function set_target_measure_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.measure)
    if not requested then return end
    if requested < MEASURE_MIN or requested > MEASURE_MAX then return end

    local value = math.floor(requested)
    local ok = pcall(miot.set, device, ip, token, FEEDER_SIID, TARGET_MEASURE_PIID, value)
    if ok then
        device:emit_event(measureControl.targetFeedingMeasure({value = value, unit = "g"}))
    end
end

local function feed_now_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.action, device, ip, token, FEEDER_SIID, FOOD_OUT_AIID, {})
    if ok then
        device:emit_event(operatingStatus.operatingStatus({value = "busy"}))
        device.thread:call_with_delay(3, function()
            pcall(poll_device_status, device)
        end)
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
    if not device:supports_capability_by_id(foodOutControl.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.battery.battery(100))
    device:emit_event(measureControl.targetFeedingMeasure({value = 20, unit = "g"}))
    device:emit_event(operatingStatus.operatingStatus({value = "idle"}))
    device:emit_event(foodLeftStatus.foodLeftLevel({value = "normal"}))
    device:emit_event(foodStuckStatus.foodStuckStatus({value = "normal"}))
    device:emit_event(desiccantStatus.desiccantLeftLevel({value = 100, unit = "%"}))
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

local driver = Driver("miot-xiaomi-pet-feeder-pi2001", {
    discovery = discovery.handle_discovery,
    lifecycle_handlers = {
        added = device_added,
        init = device_init,
        removed = device_removed,
        infoChanged = device_info_changed
    },
    capability_handlers = {
        [measureControl.ID] = {
            [measureControl.commands.setTargetFeedingMeasure.NAME] = set_target_measure_handler
        },
        [foodOutControl.ID] = {
            [foodOutControl.commands.feedNow.NAME] = feed_now_handler
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


