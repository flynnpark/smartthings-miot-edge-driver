-- Zhimi Air Purifier XA1 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local airPurifierModeCap = capabilities["concertmirror08464.zhimiAirXa1Mode"]
local fanLevelCap = capabilities["concertmirror08464.zhimiAirXa1FanLevel"]
local anionCap = capabilities["concertmirror08464.zhimiAirXa1Anion"]
local buzzerCap = capabilities["concertmirror08464.zhimiAirXa1Buzzer"]
local childLockCap = capabilities["concertmirror08464.zhimiAirXa1ChildLock"]
local displayCap = capabilities["concertmirror08464.zhimiAirXa1Display"]
local displayLevelCap = capabilities["concertmirror08464.zhimiAirXa1DisplayLevel"]
local shutterAngleCap = capabilities["concertmirror08464.zhimiAirXa1ShutterAngle"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "zhimi-air-purifier-xa1"

-- Exact local MIoT model: Zhimi Air Purifier XA1
-- Property mappings below come from the exact MIoT specification.
--
--   siid=2 piid=1 -> power
--   siid=2 piid=4 -> zhimiAirXa1Mode.airPurifierMode
--   siid=2 piid=3 -> zhimiAirXa1FanLevel.fanLevel
--   siid=2 piid=5 -> zhimiAirXa1Anion.anion
--   siid=3 piid=1 -> humidity
--   siid=3 piid=7 -> temperature
--   siid=3 piid=4 -> pm25
--   siid=3 piid=8 -> tvoc
--   siid=4 piid=1 -> filter
--   siid=6 piid=2 -> zhimiAirXa1Display.display
--   siid=6 piid=3 -> zhimiAirXa1DisplayLevel.displayLevel
--   siid=11 piid=10 -> zhimiAirXa1ShutterAngle.shutterAngle
--   siid=14 piid=1 -> zhimiAirXa1ChildLock.childLock
--   siid=15 piid=1 -> zhimiAirXa1Buzzer.buzzer

local AIRPURIFIERMODE_TO_ST = {
    [0] = "auto",
    [1] = "sleep",
    [2] = "favorite",
    [3] = "none"
}

local ST_TO_AIRPURIFIERMODE = {
    ["auto"] = 0,
    ["favorite"] = 2,
    ["none"] = 3,
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
    [1] = "auto",
    [2] = "brightest",
    [3] = "bright"
}

local ST_TO_DISPLAYLEVEL = {
    ["auto"] = 1,
    ["bright"] = 3,
    ["brightest"] = 2,
    ["off"] = 0
}

local SHUTTERANGLE_TO_ST = {
    [0] = "thirty",
    [1] = "sixty",
    [2] = "ninety"
}

local ST_TO_SHUTTERANGLE = {
    ["ninety"] = 2,
    ["sixty"] = 1,
    ["thirty"] = 0
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
    if not device:supports_capability_by_id("concertmirror08464.zhimiAirXa1Mode", "main") then
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
        {siid = 2, piid = 3},
        {siid = 3, piid = 1},
        {siid = 3, piid = 7},
        {siid = 3, piid = 4},
        {siid = 4, piid = 1},
        {siid = 3, piid = 8},
        {siid = 2, piid = 5},
        {siid = 15, piid = 1},
        {siid = 14, piid = 1},
        {siid = 6, piid = 2},
        {siid = 6, piid = 3},
        {siid = 11, piid = 10}
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
                elseif piid == 3 then
                    local mapped = FANLEVEL_TO_ST[value]
                    if mapped then
                        device:emit_event(fanLevelCap.fanLevel({value = mapped}))
                    end
                elseif piid == 5 then
                    device:emit_event(anionCap.anion({value = bool_to_st(value)}))
                end
            elseif siid == 3 then
                if piid == 1 then
                    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
                elseif piid == 7 then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == 4 then
                    device:emit_event(capabilities.fineDustSensor.fineDustLevel(math.floor(value)))
                elseif piid == 8 then
                    device:emit_event(capabilities.tvocMeasurement.tvocLevel({value = value, unit = "ug/m3"}))
                end
            elseif siid == 4 then
                if piid == 1 then
                    device:emit_event(capabilities.filterState.filterLifeRemaining({value = value, unit = "%"}))
                end
            elseif siid == 6 then
                if piid == 2 then
                    device:emit_event(displayCap.display({value = bool_to_st(value)}))
                elseif piid == 3 then
                    local mapped = DISPLAYLEVEL_TO_ST[value]
                    if mapped then
                        device:emit_event(displayLevelCap.displayLevel({value = mapped}))
                    end
                end
            elseif siid == 11 then
                if piid == 10 then
                    local mapped = SHUTTERANGLE_TO_ST[value]
                    if mapped then
                        device:emit_event(shutterAngleCap.shutterAngle({value = mapped}))
                    end
                end
            elseif siid == 14 then
                if piid == 1 then
                    device:emit_event(childLockCap.childLock({value = bool_to_st(value)}))
                end
            elseif siid == 15 then
                if piid == 1 then
                    device:emit_event(buzzerCap.buzzer({value = bool_to_st(value)}))
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

    local ok = pcall(miot.set, device, ip, token, 2, 3, value)
    if ok then
        device:emit_event(fanLevelCap.fanLevel({value = requested}))
    end
end

local function set_anion_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.anion
    local ok = pcall(miot.set, device, ip, token, 2, 5, requested == "on")
    if ok then
        device:emit_event(anionCap.anion({value = requested}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.buzzer
    local ok = pcall(miot.set, device, ip, token, 15, 1, requested == "on")
    if ok then
        device:emit_event(buzzerCap.buzzer({value = requested}))
    end
end

local function set_childLock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.childLock
    local ok = pcall(miot.set, device, ip, token, 14, 1, requested == "on")
    if ok then
        device:emit_event(childLockCap.childLock({value = requested}))
    end
end

local function set_display_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.display
    local ok = pcall(miot.set, device, ip, token, 6, 2, requested == "on")
    if ok then
        device:emit_event(displayCap.display({value = requested}))
    end
end

local function set_displayLevel_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.displayLevel
    local value = ST_TO_DISPLAYLEVEL[requested]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, 6, 3, value)
    if ok then
        device:emit_event(displayLevelCap.displayLevel({value = requested}))
    end
end

local function set_shutterAngle_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = command.args.shutterAngle
    local value = ST_TO_SHUTTERANGLE[requested]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, 11, 10, value)
    if ok then
        device:emit_event(shutterAngleCap.shutterAngle({value = requested}))
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
    device:emit_event(displayCap.display({value = "off"}))
    device:emit_event(displayLevelCap.displayLevel({value = "off"}))
    device:emit_event(shutterAngleCap.shutterAngle({value = "thirty"}))
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

local driver = Driver("miot-zhimi-air-purifier-xa1", {
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
        [displayCap.ID] = {
            [displayCap.commands.setDisplay.NAME] = set_display_handler
        },
        [displayLevelCap.ID] = {
            [displayLevelCap.commands.setDisplayLevel.NAME] = set_displayLevel_handler
        },
        [shutterAngleCap.ID] = {
            [shutterAngleCap.commands.setShutterAngle.NAME] = set_shutterAngle_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
