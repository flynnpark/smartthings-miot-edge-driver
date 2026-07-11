-- Mijia Smart Evaporative Cooling Fan Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local fanModeCap = capabilities["concertmirror08464.dmakerFanP44FanMode"]
local fanLevelCap = capabilities["concertmirror08464.dmakerFanP44FanLevel"]
local airCoolerCap = capabilities["concertmirror08464.dmakerFanP44AirCooler"]
local waterStatusCap = capabilities["concertmirror08464.dmakerFanP44WaterStatus"]
local indicatorLightCap = capabilities["concertmirror08464.dmakerFanP44IndicatorLight"]
local buzzerCap = capabilities["concertmirror08464.dmakerFanP44Buzzer"]
local childLockCap = capabilities["concertmirror08464.dmakerFanP44ChildLock"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "dmaker-fan-p44"

-- MIoT model: dmaker.fan.p44
-- Source: exact MIoT spec urn:miot-spec-v2:device:fan:0000A005:dmaker-p44:1.
local FAN_SIID = 2
local POWER_PIID = 1
local FAN_LEVEL_PIID = 2         -- 1..4
local MODE_PIID = 3              -- 0=straight, 1=natural, 2=sleep, 3=cold air
local SWING_PIID = 4
local AIR_COOLER_PIID = 6
local FAULT_PIID = 7             -- 0=normal, 1=lack water, 2=disconnected

local INDICATOR_LIGHT_SIID = 4
local INDICATOR_LIGHT_PIID = 1
local BUZZER_SIID = 5
local BUZZER_PIID = 1
local CHILD_LOCK_SIID = 7
local CHILD_LOCK_PIID = 1

local MODE_TO_ST = {
    [0] = "normal",
    [1] = "nature",
    [2] = "sleep",
    [3] = "coldAir"
}

local ST_TO_MODE = {
    normal = 0,
    nature = 1,
    sleep = 2,
    coldAir = 3
}

local WATER_STATUS_TO_ST = {
    [0] = "normal",
    [1] = "lackWater",
    [2] = "disconnected"
}

local SUPPORTED_OSCILLATION_MODES = {"off", "horizontal"}

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token
    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(fanLevelCap.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

local function emit_on_off(device, capability_attr, value)
    device:emit_event(capability_attr({value = value and "on" or "off"}))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then return end

    local properties = {
        {siid = FAN_SIID, piid = POWER_PIID},
        {siid = FAN_SIID, piid = FAN_LEVEL_PIID},
        {siid = FAN_SIID, piid = MODE_PIID},
        {siid = FAN_SIID, piid = SWING_PIID},
        {siid = FAN_SIID, piid = AIR_COOLER_PIID},
        {siid = FAN_SIID, piid = FAULT_PIID},
        {siid = INDICATOR_LIGHT_SIID, piid = INDICATOR_LIGHT_PIID},
        {siid = BUZZER_SIID, piid = BUZZER_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID}
    }

    local ok, response = pcall(miot.gets, device, ip, token, properties)
    if not ok or not response or not response.result then return end

    for _, result in ipairs(response.result) do
        if result.code == 0 then
            local siid = result.siid
            local piid = result.piid
            local value = result.value

            if siid == FAN_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == FAN_LEVEL_PIID then
                    device:emit_event(fanLevelCap.fanLevel({value = tostring(value)}))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(fanModeCap.fanMode({value = mode}))
                    end
                elseif piid == SWING_PIID then
                    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(value and "horizontal" or "off"))
                elseif piid == AIR_COOLER_PIID then
                    emit_on_off(device, airCoolerCap.airCooler, value)
                elseif piid == FAULT_PIID then
                    local water_status = WATER_STATUS_TO_ST[value]
                    if water_status then
                        device:emit_event(waterStatusCap.waterStatus({value = water_status}))
                    end
                end
            elseif siid == INDICATOR_LIGHT_SIID and piid == INDICATOR_LIGHT_PIID then
                emit_on_off(device, indicatorLightCap.indicatorLight, value)
            elseif siid == BUZZER_SIID and piid == BUZZER_PIID then
                emit_on_off(device, buzzerCap.buzzer, value)
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                emit_on_off(device, childLockCap.childLock, value)
            end
        end
    end
end

local function start_polling_timer(device)
    local timer = device.thread:call_on_schedule(device.preferences.pollingInterval or DEFAULT_POLLING_INTERVAL, function()
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
    if pcall(miot.set, device, ip, token, FAN_SIID, POWER_PIID, true) then
        device:emit_event(capabilities.switch.switch.on())
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function switch_off_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end
    if pcall(miot.set, device, ip, token, FAN_SIID, POWER_PIID, false) then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_fan_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end
    local level = tonumber(command.args.fanLevel)
    if not level then return end
    if pcall(miot.set, device, ip, token, FAN_SIID, FAN_LEVEL_PIID, level) then
        device:emit_event(fanLevelCap.fanLevel({value = tostring(level)}))
    end
end

local function set_fan_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end
    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end
    if pcall(miot.set, device, ip, token, FAN_SIID, MODE_PIID, value) then
        device:emit_event(fanModeCap.fanMode({value = mode}))
    end
end

local function set_oscillation_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end
    local mode = command.args.fanOscillationMode
    if mode ~= "off" and mode ~= "horizontal" then return end
    if pcall(miot.set, device, ip, token, FAN_SIID, SWING_PIID, mode == "horizontal") then
        device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(mode))
    end
end

local function set_air_cooler_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end
    local air_cooler = command.args.airCooler
    if pcall(miot.set, device, ip, token, FAN_SIID, AIR_COOLER_PIID, air_cooler == "on") then
        device:emit_event(airCoolerCap.airCooler({value = air_cooler}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end
    local indicator_light = command.args.indicatorLight
    if pcall(miot.set, device, ip, token, INDICATOR_LIGHT_SIID, INDICATOR_LIGHT_PIID, indicator_light == "on") then
        device:emit_event(indicatorLightCap.indicatorLight({value = indicator_light}))
    end
end

local function set_buzzer_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end
    local buzzer = command.args.buzzer
    if pcall(miot.set, device, ip, token, BUZZER_SIID, BUZZER_PIID, buzzer == "on") then
        device:emit_event(buzzerCap.buzzer({value = buzzer}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end
    local child_lock = command.args.childLock
    if pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, child_lock == "on") then
        device:emit_event(childLockCap.childLock({value = child_lock}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(fanLevelCap.fanLevel({value = "1"}))
    device:emit_event(fanModeCap.fanMode({value = "normal"}))
    device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes({value = SUPPORTED_OSCILLATION_MODES}))
    device:emit_event(capabilities.fanOscillationMode.fanOscillationMode("off"))
    device:emit_event(airCoolerCap.airCooler({value = "off"}))
    device:emit_event(waterStatusCap.waterStatus({value = "normal"}))
    device:emit_event(indicatorLightCap.indicatorLight({value = "on"}))
    device:emit_event(buzzerCap.buzzer({value = "off"}))
    device:emit_event(childLockCap.childLock({value = "off"}))
end

local function device_init(_, device)
    ensure_profile(device)
    device:online()
    if get_device_config(device) then
        start_polling_timer(device)
        pcall(poll_device_status, device)
    end
end

local function device_removed(_, device)
    stop_polling_timer(device)
end

local function device_info_changed(driver, device, _, args)
    ensure_profile(device)
    if not args.old_st_store or not args.old_st_store.preferences then return end
    local old = args.old_st_store.preferences
    local new = device.preferences
    if old.createDev == false and new.createDev == true then
        discovery.create_device(driver)
    end
    if old.ipAddress ~= new.ipAddress or old.token ~= new.token or old.pollingInterval ~= new.pollingInterval then
        stop_polling_timer(device)
        if get_device_config(device) then
            start_polling_timer(device)
            pcall(poll_device_status, device)
        end
    end
end

local driver = Driver("miot-dmaker-fan-p44", {
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
        [fanLevelCap.ID] = {
            [fanLevelCap.commands.setFanLevel.NAME] = set_fan_level_handler
        },
        [fanModeCap.ID] = {
            [fanModeCap.commands.setFanMode.NAME] = set_fan_mode_handler
        },
        [capabilities.fanOscillationMode.ID] = {
            [capabilities.fanOscillationMode.commands.setFanOscillationMode.NAME] = set_oscillation_handler
        },
        [airCoolerCap.ID] = {
            [airCoolerCap.commands.setAirCooler.NAME] = set_air_cooler_handler
        },
        [indicatorLightCap.ID] = {
            [indicatorLightCap.commands.setIndicatorLight.NAME] = set_indicator_light_handler
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
