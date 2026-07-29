-- Airdog Air Purifier MN Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local modeCap = capabilities["concertmirror08464.airdogAirMnMode"]
local fanLevelCap = capabilities["concertmirror08464.airdogAirMnFanLevel"]
local childLockCap = capabilities["concertmirror08464.airdogAirMnChildLock"]
local sleepCap = capabilities["concertmirror08464.airdogAirMnSleep"]
local smartLightCap = capabilities["concertmirror08464.airdogAirMnSmartLight"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "airdog-air-purifier-mn"

-- MIoT model: airdog.airpurifier.mn
-- specModel: airdog-mn
-- URN: urn:miot-spec-v2:device:air-purifier:0000A007:airdog-mn:1
--
-- Air Purifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, single no-fault value, not exposed
--   piid=4 mode, uint8, RW enum: 0=auto, 1=manual, 2=sleep
--   piid=5 fan-level, uint8, RW enum: 1..4
-- Environment service (siid=3)
--   piid=4 pm2.5-density, uint16, R, 0..1000
-- Filter service (siid=4): only a reset action, not exposed
-- Lock service (siid=5)
--   piid=1 zlock, bool, RW (child lock)
--   piid=2 sleep, bool, RW
--   piid=3 lighting-smart, bool, RW

local PURIFIER_SIID = 2
local POWER_PIID = 1
local MODE_PIID = 4
local FAN_LEVEL_PIID = 5

local ENVIRONMENT_SIID = 3
local PM25_PIID = 4

local LOCK_SIID = 5
local CHILD_LOCK_PIID = 1
local SLEEP_PIID = 2
local SMART_LIGHT_PIID = 3

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [0] = "auto",
    [1] = "manual",
    [2] = "sleep"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    auto = 0,
    manual = 1,
    sleep = 2
}

local FAN_LEVEL_TO_ST = {
    [1] = "level1",
    [2] = "level2",
    [3] = "level3",
    [4] = "level4"
}

local ST_TO_FAN_LEVEL = {
    level1 = 1,
    level2 = 2,
    level3 = 3,
    level4 = 4
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
    if not device:supports_capability_by_id(modeCap.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
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
        {siid = PURIFIER_SIID, piid = POWER_PIID},
        {siid = PURIFIER_SIID, piid = MODE_PIID},
        {siid = PURIFIER_SIID, piid = FAN_LEVEL_PIID},
        {siid = ENVIRONMENT_SIID, piid = PM25_PIID},
        {siid = LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = LOCK_SIID, piid = SLEEP_PIID},
        {siid = LOCK_SIID, piid = SMART_LIGHT_PIID}
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

            if siid == PURIFIER_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(bool_to_st(value)))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(modeCap.airPurifierMode({value = mode}))
                    end
                elseif piid == FAN_LEVEL_PIID then
                    local level = FAN_LEVEL_TO_ST[value]
                    if level then
                        device:emit_event(fanLevelCap.fanLevel({value = level}))
                    end
                end
            elseif siid == ENVIRONMENT_SIID and piid == PM25_PIID then
                device:emit_event(capabilities.dustSensor.fineDustLevel(math.floor(value)))
            elseif siid == LOCK_SIID then
                if piid == CHILD_LOCK_PIID then
                    device:emit_event(childLockCap.childLock({value = bool_to_st(value)}))
                elseif piid == SLEEP_PIID then
                    device:emit_event(sleepCap.sleepMode({value = bool_to_st(value)}))
                elseif piid == SMART_LIGHT_PIID then
                    device:emit_event(smartLightCap.smartLight({value = bool_to_st(value)}))
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

    local ok = pcall(miot.set, device, ip, token, PURIFIER_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, PURIFIER_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.airPurifierMode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, PURIFIER_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(modeCap.airPurifierMode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_fan_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = command.args.fanLevel
    local value = ST_TO_FAN_LEVEL[level]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, PURIFIER_SIID, FAN_LEVEL_PIID, value)
    if ok then
        device:emit_event(fanLevelCap.fanLevel({value = level}))
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

local set_child_lock_handler = make_bool_handler(LOCK_SIID, CHILD_LOCK_PIID, childLockCap, "childLock", "childLock")
local set_sleep_handler = make_bool_handler(LOCK_SIID, SLEEP_PIID, sleepCap, "sleepMode", "sleepMode")
local set_smart_light_handler = make_bool_handler(LOCK_SIID, SMART_LIGHT_PIID, smartLightCap, "smartLight", "smartLight")

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:online()
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(modeCap.airPurifierMode({value = "auto"}))
    device:emit_event(fanLevelCap.fanLevel({value = "level1"}))
    device:emit_event(capabilities.dustSensor.fineDustLevel(0))
    device:emit_event(childLockCap.childLock({value = "off"}))
    device:emit_event(sleepCap.sleepMode({value = "off"}))
    device:emit_event(smartLightCap.smartLight({value = "off"}))
    pcall(poll_device_status, device)
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

local driver = Driver("miot-airdog-air-purifier-mn", {
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
            [modeCap.commands.setAirPurifierMode.NAME] = set_mode_handler
        },
        [fanLevelCap.ID] = {
            [fanLevelCap.commands.setFanLevel.NAME] = set_fan_level_handler
        },
        [childLockCap.ID] = {
            [childLockCap.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [sleepCap.ID] = {
            [sleepCap.commands.setSleepMode.NAME] = set_sleep_handler
        },
        [smartLightCap.ID] = {
            [smartLightCap.commands.setSmartLight.NAME] = set_smart_light_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
