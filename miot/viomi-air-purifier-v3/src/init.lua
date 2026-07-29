-- Viomi Air Purifier V3 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local modeCap = capabilities["concertmirror08464.viomiAirV3Mode"]
local filterLifeCap = capabilities["concertmirror08464.viomiAirV3FilterLife"]
local uvCap = capabilities["concertmirror08464.viomiAirV3Uv"]
local indicatorCap = capabilities["concertmirror08464.viomiAirV3Indicator"]
local buzzerCap = capabilities["concertmirror08464.viomiAirV3Buzzer"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "viomi-air-purifier-v3"

-- MIoT model: viomi.airp.v3
-- specModel: viomi-v3
-- URN: urn:miot-spec-v2:device:air-purifier:0000A007:viomi-v3:1
--
-- Air Purifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, raw code, not exposed
--   piid=4 mode, uint8, RW enum: 0=strong, 1=smart, 2=sleep
--   piid=7 uv, bool, RW (UV sterilization lamp)
-- Environment service (siid=3)
--   piid=1 pm2.5-density, float, R
--   piid=2 air-quality, uint8, R enum, duplicates the PM2.5 reading, so it is
--     not exposed separately
-- Filter service (siid=4): declares no properties on this model
-- Indicator Light service (siid=5)
--   piid=1 on, bool, RW
-- Alarm service (siid=6)
--   piid=1 alarm, bool, RW
-- viomi-air-purifier service (siid=7)
--   piid=1 strainer-a-life, uint8, R, percent
--   piid=2 strainer-a-time is a cumulative hour counter, not exposed

local PURIFIER_SIID = 2
local POWER_PIID = 1
local MODE_PIID = 4
local UV_PIID = 7

local ENVIRONMENT_SIID = 3
local PM25_PIID = 1

local INDICATOR_SIID = 5
local INDICATOR_PIID = 1

local ALARM_SIID = 6
local ALARM_PIID = 1

local CUSTOM_SIID = 7
local STRAINER_LIFE_PIID = 1

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [0] = "strong",
    [1] = "smart",
    [2] = "sleep"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    strong = 0,
    smart = 1,
    sleep = 2
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
        {siid = PURIFIER_SIID, piid = UV_PIID},
        {siid = ENVIRONMENT_SIID, piid = PM25_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = CUSTOM_SIID, piid = STRAINER_LIFE_PIID}
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
                elseif piid == UV_PIID then
                    device:emit_event(uvCap.uv({value = bool_to_st(value)}))
                end
            elseif siid == ENVIRONMENT_SIID and piid == PM25_PIID then
                device:emit_event(capabilities.dustSensor.fineDustLevel(math.floor(value)))
            elseif siid == INDICATOR_SIID and piid == INDICATOR_PIID then
                device:emit_event(indicatorCap.indicatorLight({value = bool_to_st(value)}))
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                device:emit_event(buzzerCap.buzzer({value = bool_to_st(value)}))
            elseif siid == CUSTOM_SIID and piid == STRAINER_LIFE_PIID then
                device:emit_event(filterLifeCap.filterLife({value = value, unit = "%"}))
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

local set_uv_handler = make_bool_handler(PURIFIER_SIID, UV_PIID, uvCap, "uv", "uv")
local set_indicator_handler = make_bool_handler(INDICATOR_SIID, INDICATOR_PIID, indicatorCap, "indicatorLight", "indicatorLight")
local set_buzzer_handler = make_bool_handler(ALARM_SIID, ALARM_PIID, buzzerCap, "buzzer", "buzzer")

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:online()
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(modeCap.airPurifierMode({value = "smart"}))
    device:emit_event(capabilities.dustSensor.fineDustLevel(0))
    device:emit_event(filterLifeCap.filterLife({value = 100, unit = "%"}))
    device:emit_event(uvCap.uv({value = "off"}))
    device:emit_event(indicatorCap.indicatorLight({value = "on"}))
    device:emit_event(buzzerCap.buzzer({value = "off"}))
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

local driver = Driver("miot-viomi-air-purifier-v3", {
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
        [uvCap.ID] = {
            [uvCap.commands.setUv.NAME] = set_uv_handler
        },
        [indicatorCap.ID] = {
            [indicatorCap.commands.setIndicatorLight.NAME] = set_indicator_handler
        },
        [buzzerCap.ID] = {
            [buzzerCap.commands.setBuzzer.NAME] = set_buzzer_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
