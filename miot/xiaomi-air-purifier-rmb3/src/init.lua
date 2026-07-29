-- Xiaomi Air Purifier RMB3 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local airPurifierModeCap = capabilities["concertmirror08464.xiaomiAirRmb3Mode"]
local fanLevelCap = capabilities["concertmirror08464.xiaomiAirRmb3FanLevel"]
local buzzerCap = capabilities["concertmirror08464.xiaomiAirRmb3Buzzer"]
local childLockCap = capabilities["concertmirror08464.xiaomiAirRmb3ChildLock"]
local displayLevelCap = capabilities["concertmirror08464.xiaomiAirRmb3DisplayLevel"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "xiaomi-air-purifier-rmb3"

-- Exact local MIoT model: Xiaomi Air Purifier RMB3
-- Property mappings below come from the exact MIoT specification.
--
--   siid=2 piid=1 -> power
--   siid=2 piid=3 -> xiaomiAirRmb3Mode.airPurifierMode
--   siid=3 piid=1 -> humidity
--   siid=3 piid=2 -> temperature
--   siid=3 piid=4 -> pm25
--   siid=4 piid=1 -> filter
--   siid=6 piid=2 -> xiaomiAirRmb3DisplayLevel.displayLevel
--   siid=7 piid=1 -> xiaomiAirRmb3Buzzer.buzzer
--   siid=8 piid=1 -> xiaomiAirRmb3ChildLock.childLock
--   siid=9 piid=1 -> xiaomiAirRmb3FanLevel.fanLevel

local AIRPURIFIERMODE_TO_ST = {
    [0] = "auto",
    [1] = "sleep",
    [2] = "favorite"
}

local ST_TO_AIRPURIFIERMODE = {
    ["auto"] = 0,
    ["favorite"] = 2,
    ["sleep"] = 1
}

local FANLEVEL_TO_ST = {
    [0] = "level0",
    [1] = "level1",
    [2] = "level2",
    [3] = "level3",
    [4] = "level4",
    [5] = "level5",
    [6] = "level6",
    [7] = "level7",
    [8] = "level8",
    [9] = "level9",
    [10] = "level10",
    [11] = "level11",
    [12] = "level12",
    [13] = "level13",
    [14] = "level14"
}

local ST_TO_FANLEVEL = {
    ["level0"] = 0,
    ["level1"] = 1,
    ["level10"] = 10,
    ["level11"] = 11,
    ["level12"] = 12,
    ["level13"] = 13,
    ["level14"] = 14,
    ["level2"] = 2,
    ["level3"] = 3,
    ["level4"] = 4,
    ["level5"] = 5,
    ["level6"] = 6,
    ["level7"] = 7,
    ["level8"] = 8,
    ["level9"] = 9
}

local DISPLAYLEVEL_TO_ST = {
    [0] = "off",
    [1] = "dim",
    [2] = "bright"
}

local ST_TO_DISPLAYLEVEL = {
    ["bright"] = 2,
    ["dim"] = 1,
    ["off"] = 0
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
    if not device:supports_capability_by_id("concertmirror08464.xiaomiAirRmb3Mode", "main") then
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
        {siid = 2, piid = 1},
        {siid = 2, piid = 3},
        {siid = 9, piid = 1},
        {siid = 3, piid = 1},
        {siid = 3, piid = 2},
        {siid = 3, piid = 4},
        {siid = 4, piid = 1},
        {siid = 7, piid = 1},
        {siid = 8, piid = 1},
        {siid = 6, piid = 2}
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

            if siid == 2 then
                if piid == 1 then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == 3 then
                    local mapped = AIRPURIFIERMODE_TO_ST[value]
                    if mapped then
                        device:emit_event(airPurifierModeCap.airPurifierMode({value = mapped}))
                    end
                end
            elseif siid == 3 then
                if piid == 1 then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                elseif piid == 2 then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == 4 then
                    device:emit_event(capabilities.fineDustSensor.fineDustLevel(math.floor(value)))
                end
            elseif siid == 4 then
                if piid == 1 then
                    device:emit_event(capabilities.filterState.filterLifeRemaining({value = value, unit = "%"}))
                end
            elseif siid == 6 then
                if piid == 2 then
                    local mapped = DISPLAYLEVEL_TO_ST[value]
                    if mapped then
                        device:emit_event(displayLevelCap.displayLevel({value = mapped}))
                    end
                end
            elseif siid == 7 then
                if piid == 1 then
                    device:emit_event(buzzerCap.buzzer({value = bool_to_st(value)}))
                end
            elseif siid == 8 then
                if piid == 1 then
                    device:emit_event(childLockCap.childLock({value = bool_to_st(value)}))
                end
            elseif siid == 9 then
                if piid == 1 then
                    local mapped = FANLEVEL_TO_ST[value]
                    if mapped then
                        device:emit_event(fanLevelCap.fanLevel({value = mapped}))
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

    local ok = pcall(miot.set, device, ip, token, 2, 1, true)
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

    local ok = pcall(miot.set, device, ip, token, 2, 1, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_airPurifierMode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.airPurifierMode
    local value = ST_TO_AIRPURIFIERMODE[requested]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, 2, 3, value)
    if ok then
        device:emit_event(airPurifierModeCap.airPurifierMode({value = requested}))
    end
end

local function set_fanLevel_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.fanLevel
    local value = ST_TO_FANLEVEL[requested]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, 9, 1, value)
    if ok then
        device:emit_event(fanLevelCap.fanLevel({value = requested}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.buzzer
    local ok = pcall(miot.set, device, ip, token, 7, 1, requested == "on")
    if ok then
        device:emit_event(buzzerCap.buzzer({value = requested}))
    end
end

local function set_childLock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.childLock
    local ok = pcall(miot.set, device, ip, token, 8, 1, requested == "on")
    if ok then
        device:emit_event(childLockCap.childLock({value = requested}))
    end
end

local function set_displayLevel_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.displayLevel
    local value = ST_TO_DISPLAYLEVEL[requested]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, 6, 2, value)
    if ok then
        device:emit_event(displayLevelCap.displayLevel({value = requested}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:online()
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(airPurifierModeCap.airPurifierMode({value = "auto"}))
    device:emit_event(fanLevelCap.fanLevel({value = "level0"}))
    device:emit_event(buzzerCap.buzzer({value = "off"}))
    device:emit_event(childLockCap.childLock({value = "off"}))
    device:emit_event(displayLevelCap.displayLevel({value = "off"}))
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

local driver = Driver("miot-xiaomi-air-purifier-rmb3", {
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
        [airPurifierModeCap.ID] = {
            [airPurifierModeCap.commands.setAirPurifierMode.NAME] = set_airPurifierMode_handler
        },
        [fanLevelCap.ID] = {
            [fanLevelCap.commands.setFanLevel.NAME] = set_fanLevel_handler
        },
        [buzzerCap.ID] = {
            [buzzerCap.commands.setBuzzer.NAME] = set_buzzer_handler
        },
        [childLockCap.ID] = {
            [childLockCap.commands.setChildLock.NAME] = set_childLock_handler
        },
        [displayLevelCap.ID] = {
            [displayLevelCap.commands.setDisplayLevel.NAME] = set_displayLevel_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
