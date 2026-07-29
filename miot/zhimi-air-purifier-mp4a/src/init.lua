-- Zhimi Air Purifier MP4A Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local airPurifierModeCap = capabilities["concertmirror08464.zhimiAirMp4aMode"]
local fanLevelCap = capabilities["concertmirror08464.zhimiAirMp4aFanLevel"]
local anionCap = capabilities["concertmirror08464.zhimiAirMp4aAnion"]
local buzzerCap = capabilities["concertmirror08464.zhimiAirMp4aBuzzer"]
local childLockCap = capabilities["concertmirror08464.zhimiAirMp4aChildLock"]
local displayLevelCap = capabilities["concertmirror08464.zhimiAirMp4aDisplayLevel"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "zhimi-air-purifier-mp4a"

-- Exact local MIoT model: Zhimi Air Purifier MP4A
-- Property mappings below come from the exact MIoT specification.
--
--   siid=2 piid=1 -> power
--   siid=2 piid=4 -> zhimiAirMp4aMode.airPurifierMode
--   siid=2 piid=5 -> zhimiAirMp4aFanLevel.fanLevel
--   siid=2 piid=6 -> zhimiAirMp4aAnion.anion
--   siid=3 piid=1 -> humidity
--   siid=3 piid=7 -> temperature
--   siid=3 piid=4 -> pm25
--   siid=4 piid=1 -> filter
--   siid=6 piid=1 -> zhimiAirMp4aBuzzer.buzzer
--   siid=8 piid=1 -> zhimiAirMp4aChildLock.childLock
--   siid=13 piid=2 -> zhimiAirMp4aDisplayLevel.displayLevel

local AIRPURIFIERMODE_TO_ST = {
    [0] = "auto",
    [1] = "sleep",
    [2] = "favorite",
    [3] = "manual"
}

local ST_TO_AIRPURIFIERMODE = {
    ["auto"] = 0,
    ["favorite"] = 2,
    ["manual"] = 3,
    ["sleep"] = 1
}

local FANLEVEL_TO_ST = {
    [1] = "level1",
    [2] = "level2",
    [3] = "level3"
}

local ST_TO_FANLEVEL = {
    ["level1"] = 1,
    ["level2"] = 2,
    ["level3"] = 3
}

local DISPLAYLEVEL_TO_ST = {
    [0] = "off",
    [1] = "bright",
    [2] = "brightest"
}

local ST_TO_DISPLAYLEVEL = {
    ["bright"] = 1,
    ["brightest"] = 2,
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
    if not device:supports_capability_by_id("concertmirror08464.zhimiAirMp4aMode", "main") then
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
        {siid = 2, piid = 4},
        {siid = 2, piid = 5},
        {siid = 3, piid = 1},
        {siid = 3, piid = 7},
        {siid = 3, piid = 4},
        {siid = 4, piid = 1},
        {siid = 2, piid = 6},
        {siid = 6, piid = 1},
        {siid = 8, piid = 1},
        {siid = 13, piid = 2}
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
                elseif piid == 4 then
                    local mapped = AIRPURIFIERMODE_TO_ST[value]
                    if mapped then
                        device:emit_event(airPurifierModeCap.airPurifierMode({value = mapped}))
                    end
                elseif piid == 5 then
                    local mapped = FANLEVEL_TO_ST[value]
                    if mapped then
                        device:emit_event(fanLevelCap.fanLevel({value = mapped}))
                    end
                elseif piid == 6 then
                    device:emit_event(anionCap.anion({value = bool_to_st(value)}))
                end
            elseif siid == 3 then
                if piid == 1 then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                elseif piid == 7 then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == 4 then
                    device:emit_event(capabilities.fineDustSensor.fineDustLevel(math.floor(value)))
                end
            elseif siid == 4 then
                if piid == 1 then
                    device:emit_event(capabilities.filterState.filterLifeRemaining({value = value, unit = "%"}))
                end
            elseif siid == 6 then
                if piid == 1 then
                    device:emit_event(buzzerCap.buzzer({value = bool_to_st(value)}))
                end
            elseif siid == 8 then
                if piid == 1 then
                    device:emit_event(childLockCap.childLock({value = bool_to_st(value)}))
                end
            elseif siid == 13 then
                if piid == 2 then
                    local mapped = DISPLAYLEVEL_TO_ST[value]
                    if mapped then
                        device:emit_event(displayLevelCap.displayLevel({value = mapped}))
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

    local ok = pcall(miot.set, device, ip, token, 2, 4, value)
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

    local ok = pcall(miot.set, device, ip, token, 2, 5, value)
    if ok then
        device:emit_event(fanLevelCap.fanLevel({value = requested}))
    end
end

local function set_anion_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.anion
    local ok = pcall(miot.set, device, ip, token, 2, 6, requested == "on")
    if ok then
        device:emit_event(anionCap.anion({value = requested}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.buzzer
    local ok = pcall(miot.set, device, ip, token, 6, 1, requested == "on")
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

    local ok = pcall(miot.set, device, ip, token, 13, 2, value)
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
    device:emit_event(fanLevelCap.fanLevel({value = "level1"}))
    device:emit_event(anionCap.anion({value = "off"}))
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

local driver = Driver("miot-zhimi-air-purifier-mp4a", {
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
        [anionCap.ID] = {
            [anionCap.commands.setAnion.NAME] = set_anion_handler
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
