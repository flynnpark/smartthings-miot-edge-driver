-- Xiaomi Water Purifier LX20 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local operatingStatus = capabilities["concertmirror08464.xiaomiPuriLx20Status"]
local waterModeControl = capabilities["concertmirror08464.xiaomiPuriLx20SaveMode"]
local tdsInStatus = capabilities["concertmirror08464.xiaomiPuriLx20TdsIn"]
local tdsOutStatus = capabilities["concertmirror08464.xiaomiPuriLx20TdsOut"]
local filterRoStatus = capabilities["concertmirror08464.xiaomiPuriLx20FilterRo"]
local filterRoTwoStatus = capabilities["concertmirror08464.xiaomiPuriLx20FilterRoTwo"]
local filterPpcStatus = capabilities["concertmirror08464.xiaomiPuriLx20FilterPpc"]
local outputStatus = capabilities["concertmirror08464.xiaomiPuriLx20Output"]
local noDisturbControl = capabilities["concertmirror08464.xiaomiPuriLx20NoDisturb"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "xiaomi-water-purifier-lx20"

-- MIoT model: xiaomi.waterpuri.lx20
-- specModel: xiaomi-lx20
-- URN: urn:miot-spec-v2:device:water-purifier:0000A013:xiaomi-lx20:2
--
-- Water Purifier service (siid=2)
--   piid=1 fault, uint32, R, raw code, not exposed
--   piid=2 status, uint8, R enum: 1=idle, 2=busy
--   piid=3 temperature, int8, R, celsius
--   piid=4 no-old-water-mode, uint8, RW enum: 0=default, 1=quality, 2=save
--   piid=5 pipeline-connection, piid=7 holiday-mode: installation and away
--     settings, not exposed
--   aiid=1 stop-production, action, not exposed
-- RO 400 Filter service (siid=3)
--   piid=1 filter-life-level, uint8, R, 0..100 %
--   remaining piids are used time/flow counters, not exposed
-- Total Dissolved Solids Sensor service (siid=4)
--   piid=1 tds-in, uint16, R, ppm
--   piid=2 tds-out, uint16, R, ppm
-- RO 800 Filter service (siid=5)
--   piid=1 filter-life-level, uint8, R, 0..100 %
-- No Disturb service (siid=6)
--   piid=1 no-disturb, bool, RW
-- Water Use Details service (siid=8)
--   piid=2 pure-water-output, uint16, R, mL
--   piid=1 production time is a cumulative counter, not exposed
-- PPC Filter service (siid=9)
--   piid=1 filter-life-level, uint8, R, 0..100 %

local PURIFIER_SIID = 2
local STATUS_PIID = 2
local TEMPERATURE_PIID = 3
local WATER_MODE_PIID = 4

local FILTER_RO_SIID = 3
local TDS_SIID = 4
local TDS_IN_PIID = 1
local TDS_OUT_PIID = 2
local FILTER_RO_TWO_SIID = 5
local FILTER_LIFE_PIID = 1

local NO_DISTURB_SIID = 6
local NO_DISTURB_PIID = 1

local WATER_USE_SIID = 8
local PURE_WATER_OUTPUT_PIID = 2

local FILTER_PPC_SIID = 9

-- MIoT -> SmartThings
local STATUS_TO_ST = {
    [1] = "idle",
    [2] = "busy"
}

local WATER_MODE_TO_ST = {
    [0] = "default",
    [1] = "quality",
    [2] = "save"
}

-- SmartThings -> MIoT
local ST_TO_WATER_MODE = {
    default = 0,
    quality = 1,
    save = 2
}

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
        {siid = PURIFIER_SIID, piid = STATUS_PIID},
        {siid = PURIFIER_SIID, piid = TEMPERATURE_PIID},
        {siid = PURIFIER_SIID, piid = WATER_MODE_PIID},
        {siid = FILTER_RO_SIID, piid = FILTER_LIFE_PIID},
        {siid = TDS_SIID, piid = TDS_IN_PIID},
        {siid = TDS_SIID, piid = TDS_OUT_PIID},
        {siid = FILTER_RO_TWO_SIID, piid = FILTER_LIFE_PIID},
        {siid = NO_DISTURB_SIID, piid = NO_DISTURB_PIID},
        {siid = WATER_USE_SIID, piid = PURE_WATER_OUTPUT_PIID},
        {siid = FILTER_PPC_SIID, piid = FILTER_LIFE_PIID}
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
                if piid == STATUS_PIID then
                    local status = STATUS_TO_ST[value]
                    if status then
                        device:emit_event(operatingStatus.operatingStatus({value = status}))
                    end
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == WATER_MODE_PIID then
                    local mode = WATER_MODE_TO_ST[value]
                    if mode then
                        device:emit_event(waterModeControl.waterMode({value = mode}))
                    end
                end
            elseif siid == FILTER_RO_SIID and piid == FILTER_LIFE_PIID then
                device:emit_event(filterRoStatus.filterLifeLevel({value = value, unit = "%"}))
            elseif siid == TDS_SIID then
                if piid == TDS_IN_PIID then
                    device:emit_event(tdsInStatus.tdsIn({value = value, unit = "ppm"}))
                elseif piid == TDS_OUT_PIID then
                    device:emit_event(tdsOutStatus.tdsOut({value = value, unit = "ppm"}))
                end
            elseif siid == FILTER_RO_TWO_SIID and piid == FILTER_LIFE_PIID then
                device:emit_event(filterRoTwoStatus.filterLifeLevel({value = value, unit = "%"}))
            elseif siid == NO_DISTURB_SIID and piid == NO_DISTURB_PIID then
                device:emit_event(noDisturbControl.noDisturb({value = value and "on" or "off"}))
            elseif siid == WATER_USE_SIID and piid == PURE_WATER_OUTPUT_PIID then
                device:emit_event(outputStatus.pureWaterOutput({value = value, unit = "mL"}))
            elseif siid == FILTER_PPC_SIID and piid == FILTER_LIFE_PIID then
                device:emit_event(filterPpcStatus.filterLifeLevel({value = value, unit = "%"}))
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

local function set_water_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.waterMode
    local value = ST_TO_WATER_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, PURIFIER_SIID, WATER_MODE_PIID, value)
    if ok then
        device:emit_event(waterModeControl.waterMode({value = mode}))
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
    if not device:supports_capability_by_id(waterModeControl.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(operatingStatus.operatingStatus({value = "idle"}))
    device:emit_event(waterModeControl.waterMode({value = "default"}))
    device:emit_event(tdsInStatus.tdsIn({value = 0, unit = "ppm"}))
    device:emit_event(tdsOutStatus.tdsOut({value = 0, unit = "ppm"}))
    device:emit_event(filterRoStatus.filterLifeLevel({value = 100, unit = "%"}))
    device:emit_event(filterRoTwoStatus.filterLifeLevel({value = 100, unit = "%"}))
    device:emit_event(filterPpcStatus.filterLifeLevel({value = 100, unit = "%"}))
    device:emit_event(outputStatus.pureWaterOutput({value = 0, unit = "mL"}))
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

local driver = Driver("miot-xiaomi-water-purifier-lx20", {
    discovery = discovery.handle_discovery,
    lifecycle_handlers = {
        added = device_added,
        init = device_init,
        removed = device_removed,
        infoChanged = device_info_changed
    },
    capability_handlers = {
        [waterModeControl.ID] = {
            [waterModeControl.commands.setWaterMode.NAME] = set_water_mode_handler
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
