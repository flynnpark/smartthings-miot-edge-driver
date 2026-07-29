-- Xiaomi Water Purifier LX32 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local operatingStatus = capabilities["concertmirror08464.xiaomiPuriLx32Status"]
local waterModeControl = capabilities["concertmirror08464.xiaomiPuriLx32SaveMode"]
local tdsOutStatus = capabilities["concertmirror08464.xiaomiPuriLx32TdsOut"]
local filterOneStatus = capabilities["concertmirror08464.xiaomiPuriLx32FilterOne"]
local filterTwoStatus = capabilities["concertmirror08464.xiaomiPuriLx32FilterTwo"]
local cupControl = capabilities["concertmirror08464.xiaomiPuriLx32Cup"]
local volumeControl = capabilities["concertmirror08464.xiaomiPuriLx32Volume"]
local pipelineControl = capabilities["concertmirror08464.xiaomiPuriLx32Pipeline"]
local holidayControl = capabilities["concertmirror08464.xiaomiPuriLx32Holiday"]
local noDisturbControl = capabilities["concertmirror08464.xiaomiPuriLx32NoDisturb"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "xiaomi-water-purifier-lx32"

-- MIoT model: xiaomi.waterpuri.lx32
-- specModel: xiaomi-lx32
-- URN: urn:miot-spec-v2:device:water-purifier:0000A013:xiaomi-lx32:2
--
-- The device has no power property; it stays powered and dispenses on demand,
-- so this driver exposes no switch capability.
--
-- Water Purifier service (siid=2)
--   piid=1 fault, uint32, R, raw code, not exposed
--   piid=2 status, uint8, R enum: 1=idle, 2=busy
--   piid=3 temperature, float, R, celsius
--   piid=4 no-old-water-mode, uint8, RW enum: 0=default, 1=quality, 2=save
--   piid=5 pipeline-connection, bool, RW
--   piid=7 holiday-mode, bool, RW
--   aiid=1 stop-production, action, not exposed
-- Filter service (siid=3)
--   piid=1 filter-life-level, uint8, R, 0..100 %
--   remaining piids are used time and flow counters, not exposed
-- TDS Sensor service (siid=4)
--   piid=2 tds-out, uint16, R, ppm
-- Filter service (siid=5)
--   piid=1 filter-life-level, uint8, R, 0..100 %
-- No Disturb service (siid=6)
--   piid=1 no-disturb, bool, RW
-- Water Dispenser service (siid=7)
--   piid=2 out-water-cup, uint8, RW enum: 0=last, 1..6=cup 1..6
--   piid=3 out-water-volume, uint32, RW, mL
--   piid=1 cup-setting carries an opaque preset blob, not exposed
-- Water Use Details service (siid=8): production time, cumulative pure water
--   output, and the statistical TDS average are counters, not exposed

local PURIFIER_SIID = 2
local STATUS_PIID = 2
local TEMPERATURE_PIID = 3
local WATER_MODE_PIID = 4
local PIPELINE_PIID = 5
local HOLIDAY_PIID = 7

local FILTER_ONE_SIID = 3
local FILTER_TWO_SIID = 5
local FILTER_LIFE_PIID = 1

local TDS_SIID = 4
local TDS_OUT_PIID = 2

local NO_DISTURB_SIID = 6
local NO_DISTURB_PIID = 1

local DISPENSER_SIID = 7
local CUP_PIID = 2
local VOLUME_PIID = 3

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
    ["default"] = 0,
    quality = 1,
    save = 2
}

local CUP_TO_ST = {
    [0] = "last",
    [1] = "cup1",
    [2] = "cup2",
    [3] = "cup3",
    [4] = "cup4",
    [5] = "cup5",
    [6] = "cup6"
}

local ST_TO_CUP = {
    last = 0,
    cup1 = 1,
    cup2 = 2,
    cup3 = 3,
    cup4 = 4,
    cup5 = 5,
    cup6 = 6
}

local VOLUME_MAX = 2000

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(cupControl.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
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
        {siid = PURIFIER_SIID, piid = PIPELINE_PIID},
        {siid = PURIFIER_SIID, piid = HOLIDAY_PIID},
        {siid = FILTER_ONE_SIID, piid = FILTER_LIFE_PIID},
        {siid = FILTER_TWO_SIID, piid = FILTER_LIFE_PIID},
        {siid = TDS_SIID, piid = TDS_OUT_PIID},
        {siid = NO_DISTURB_SIID, piid = NO_DISTURB_PIID},
        {siid = DISPENSER_SIID, piid = CUP_PIID},
        {siid = DISPENSER_SIID, piid = VOLUME_PIID}
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
                        device:emit_event(operatingStatus.purifierStatus({value = status}))
                    end
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == WATER_MODE_PIID then
                    local mode = WATER_MODE_TO_ST[value]
                    if mode then
                        device:emit_event(waterModeControl.waterMode({value = mode}))
                    end
                elseif piid == PIPELINE_PIID then
                    device:emit_event(pipelineControl.pipelineConnection({value = value and "on" or "off"}))
                elseif piid == HOLIDAY_PIID then
                    device:emit_event(holidayControl.holidayMode({value = value and "on" or "off"}))
                end
            elseif siid == FILTER_ONE_SIID and piid == FILTER_LIFE_PIID then
                device:emit_event(filterOneStatus.filterLife({value = value, unit = "%"}))
            elseif siid == FILTER_TWO_SIID and piid == FILTER_LIFE_PIID then
                device:emit_event(filterTwoStatus.filterLife({value = value, unit = "%"}))
            elseif siid == TDS_SIID and piid == TDS_OUT_PIID then
                -- The property allows up to 65535, but the exposed slider stops
                -- at the 1000 ppm the vendor app displays.
                device:emit_event(tdsOutStatus.tdsOut({value = math.min(1000, value), unit = "ppm"}))
            elseif siid == NO_DISTURB_SIID and piid == NO_DISTURB_PIID then
                device:emit_event(noDisturbControl.noDisturb({value = value and "on" or "off"}))
            elseif siid == DISPENSER_SIID then
                if piid == CUP_PIID then
                    local cup = CUP_TO_ST[value]
                    if cup then
                        device:emit_event(cupControl.outWaterCup({value = cup}))
                    end
                elseif piid == VOLUME_PIID then
                    device:emit_event(volumeControl.outWaterVolume({value = math.min(VOLUME_MAX, value), unit = "mL"}))
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

local function set_cup_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local cup = command.args.outWaterCup
    local value = ST_TO_CUP[cup]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, DISPENSER_SIID, CUP_PIID, value)
    if ok then
        device:emit_event(cupControl.outWaterCup({value = cup}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_volume_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local volume = tonumber(command.args.outWaterVolume)
    if not volume then return end

    local value = math.floor(math.max(0, math.min(VOLUME_MAX, volume)))
    local ok = pcall(miot.set, device, ip, token, DISPENSER_SIID, VOLUME_PIID, value)
    if ok then
        device:emit_event(volumeControl.outWaterVolume({value = value, unit = "mL"}))
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

local set_pipeline_handler = make_bool_handler(PURIFIER_SIID, PIPELINE_PIID, pipelineControl, "pipelineConnection", "pipelineConnection")
local set_holiday_handler = make_bool_handler(PURIFIER_SIID, HOLIDAY_PIID, holidayControl, "holidayMode", "holidayMode")
local set_no_disturb_handler = make_bool_handler(NO_DISTURB_SIID, NO_DISTURB_PIID, noDisturbControl, "noDisturb", "noDisturb")

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:online()
    device:emit_event(operatingStatus.purifierStatus({value = "idle"}))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(waterModeControl.waterMode({value = "default"}))
    device:emit_event(tdsOutStatus.tdsOut({value = 0, unit = "ppm"}))
    device:emit_event(filterOneStatus.filterLife({value = 100, unit = "%"}))
    device:emit_event(filterTwoStatus.filterLife({value = 100, unit = "%"}))
    device:emit_event(cupControl.outWaterCup({value = "last"}))
    device:emit_event(volumeControl.outWaterVolume({value = 0, unit = "mL"}))
    device:emit_event(pipelineControl.pipelineConnection({value = "off"}))
    device:emit_event(holidayControl.holidayMode({value = "off"}))
    device:emit_event(noDisturbControl.noDisturb({value = "off"}))
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

local driver = Driver("miot-xiaomi-water-purifier-lx32", {
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
        [cupControl.ID] = {
            [cupControl.commands.setOutWaterCup.NAME] = set_cup_handler
        },
        [volumeControl.ID] = {
            [volumeControl.commands.setOutWaterVolume.NAME] = set_volume_handler
        },
        [pipelineControl.ID] = {
            [pipelineControl.commands.setPipelineConnection.NAME] = set_pipeline_handler
        },
        [holidayControl.ID] = {
            [holidayControl.commands.setHolidayMode.NAME] = set_holiday_handler
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
