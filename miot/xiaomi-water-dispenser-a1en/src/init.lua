-- Xiaomi Water Dispenser A1EN Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local operatingStatus = capabilities["concertmirror08464.xiaomiYsjA1enStatus"]
local waterModeControl = capabilities["concertmirror08464.xiaomiYsjA1enWaterMode"]
local cupControl = capabilities["concertmirror08464.xiaomiYsjA1enCup"]
local faultStatus = capabilities["concertmirror08464.xiaomiYsjA1enFault"]
local tdsInStatus = capabilities["concertmirror08464.xiaomiYsjA1enTdsIn"]
local tdsOutStatus = capabilities["concertmirror08464.xiaomiYsjA1enTdsOut"]
local filterOneStatus = capabilities["concertmirror08464.xiaomiYsjA1enFilterOne"]
local filterTwoStatus = capabilities["concertmirror08464.xiaomiYsjA1enFilterTwo"]
local lockControl = capabilities["concertmirror08464.xiaomiYsjA1enLock"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "xiaomi-water-dispenser-a1en"

-- MIoT model: xiaomi.ysj.a1en
-- specModel: xiaomi-a1en
-- URN: urn:miot-spec-v2:device:water-dispenser:0000A0A1:xiaomi-a1en:1
--
-- Water Dispenser service (siid=2)
--   piid=1 fault, uint8, R enum: 0=noFaults .. 9=purifiedWaterError
--   piid=3 status, uint8, R enum: 0=idle, 1=waterComingOut, 2=cleaning, 3=error, 4=purifier
--   piid=5 temperature, uint8, R, celsius
--   piid=6 target-temperature, uint8, RW range 40..95 celsius
--   piid=14 cup-setting, uint8, RW enum: 0=small, 1=middle, 2=bigger
--   piid=15 mode, uint8, RW enum: 0=roomTemperature, 1=milk, 2=coffee, 3=boilWater
--   piid=7 tap default mode, piid=8 local mode config, piid=9 clean progress,
--     piid=10 clean status, piid=11 reset status, piid=12 winter mode,
--     piid=13 raw mode, piid=16 interval reminder: auxiliary values, not exposed
--   aiid=1..3 recipe and clean actions, not exposed
-- Total Dissolved Solids Sensor service (siid=3)
--   piid=1 tds-in, uint16, R, ppm
--   piid=2 tds-out, uint16, R, ppm
-- Physical Control Locked service (siid=4)
--   piid=1 physical-controls-locked, uint8, RW enum: 0=selectOpen, 1=open, 2=close
-- Filter services (siid=5, siid=6)
--   piid=1 filter-life-level, uint8, R, 0..100 %
--   aiid=1 reset-filter-life, action, not exposed
-- Screen (siid=7) and No Disturb (siid=9): auto screen-off time and quiet
--   period scheduling, not exposed

local DISPENSER_SIID = 2
local FAULT_PIID = 1
local STATUS_PIID = 3
local TEMPERATURE_PIID = 5
local TARGET_TEMPERATURE_PIID = 6
local CUP_SETTING_PIID = 14
local WATER_MODE_PIID = 15

local TDS_SIID = 3
local TDS_IN_PIID = 1
local TDS_OUT_PIID = 2

local LOCK_SIID = 4
local LOCK_PIID = 1

local FILTER_ONE_SIID = 5
local FILTER_TWO_SIID = 6
local FILTER_LIFE_PIID = 1

-- MIoT -> SmartThings
local FAULT_TO_ST = {
    [0] = "noFaults",
    [1] = "inWaterSensor",
    [2] = "outWaterSensor",
    [3] = "communication",
    [4] = "noWaterBox",
    [5] = "noWater",
    [6] = "wasteWaterFull",
    [7] = "waterBad",
    [8] = "dryProtect",
    [9] = "purifiedWater"
}

local STATUS_TO_ST = {
    [0] = "idle",
    [1] = "waterComingOut",
    [2] = "cleaning",
    [3] = "error",
    [4] = "purifier"
}

local CUP_TO_ST = {
    [0] = "small",
    [1] = "middle",
    [2] = "bigger"
}

-- SmartThings -> MIoT
local ST_TO_CUP = {
    small = 0,
    middle = 1,
    bigger = 2
}

local WATER_MODE_TO_ST = {
    [0] = "roomTemperature",
    [1] = "milk",
    [2] = "coffee",
    [3] = "boilWater"
}

local ST_TO_WATER_MODE = {
    roomTemperature = 0,
    milk = 1,
    coffee = 2,
    boilWater = 3
}

local LOCK_TO_ST = {
    [0] = "selectOpen",
    [1] = "open",
    [2] = "close"
}

local ST_TO_LOCK = {
    selectOpen = 0,
    open = 1,
    close = 2
}

local TARGET_TEMPERATURE_MIN = 40
local TARGET_TEMPERATURE_MAX = 95

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
        {siid = DISPENSER_SIID, piid = FAULT_PIID},
        {siid = DISPENSER_SIID, piid = STATUS_PIID},
        {siid = DISPENSER_SIID, piid = TEMPERATURE_PIID},
        {siid = DISPENSER_SIID, piid = TARGET_TEMPERATURE_PIID},
        {siid = DISPENSER_SIID, piid = CUP_SETTING_PIID},
        {siid = DISPENSER_SIID, piid = WATER_MODE_PIID},
        {siid = TDS_SIID, piid = TDS_IN_PIID},
        {siid = TDS_SIID, piid = TDS_OUT_PIID},
        {siid = LOCK_SIID, piid = LOCK_PIID},
        {siid = FILTER_ONE_SIID, piid = FILTER_LIFE_PIID},
        {siid = FILTER_TWO_SIID, piid = FILTER_LIFE_PIID}
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

            if siid == DISPENSER_SIID then
                if piid == FAULT_PIID then
                    local fault = FAULT_TO_ST[value]
                    if fault then
                        device:emit_event(faultStatus.deviceFault({value = fault}))
                    end
                elseif piid == STATUS_PIID then
                    local status = STATUS_TO_ST[value]
                    if status then
                        device:emit_event(operatingStatus.operatingStatus({value = status}))
                    end
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == TARGET_TEMPERATURE_PIID then
                    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = value, unit = "C"}))
                elseif piid == CUP_SETTING_PIID then
                    local cup = CUP_TO_ST[value]
                    if cup then
                        device:emit_event(cupControl.cupSetting({value = cup}))
                    end
                elseif piid == WATER_MODE_PIID then
                    local mode = WATER_MODE_TO_ST[value]
                    if mode then
                        device:emit_event(waterModeControl.waterMode({value = mode}))
                    end
                end
            elseif siid == TDS_SIID then
                if piid == TDS_IN_PIID then
                    device:emit_event(tdsInStatus.tdsIn({value = value, unit = "ppm"}))
                elseif piid == TDS_OUT_PIID then
                    device:emit_event(tdsOutStatus.tdsOut({value = value, unit = "ppm"}))
                end
            elseif siid == LOCK_SIID and piid == LOCK_PIID then
                local lock = LOCK_TO_ST[value]
                if lock then
                    device:emit_event(lockControl.childLock({value = lock}))
                end
            elseif siid == FILTER_ONE_SIID and piid == FILTER_LIFE_PIID then
                device:emit_event(filterOneStatus.filterLifeLevel({value = value, unit = "%"}))
            elseif siid == FILTER_TWO_SIID and piid == FILTER_LIFE_PIID then
                device:emit_event(filterTwoStatus.filterLifeLevel({value = value, unit = "%"}))
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

local function set_heating_setpoint_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local setpoint = tonumber(command.args.setpoint)
    if not setpoint then return end
    if setpoint < TARGET_TEMPERATURE_MIN or setpoint > TARGET_TEMPERATURE_MAX then return end

    local value = math.floor(setpoint + 0.5)
    local ok = pcall(miot.set, device, ip, token, DISPENSER_SIID, TARGET_TEMPERATURE_PIID, value)
    if ok then
        device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = value, unit = "C"}))
    end
end

local function set_water_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.waterMode
    local value = ST_TO_WATER_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, DISPENSER_SIID, WATER_MODE_PIID, value)
    if ok then
        device:emit_event(waterModeControl.waterMode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_cup_setting_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local cup = command.args.cupSetting
    local value = ST_TO_CUP[cup]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, DISPENSER_SIID, CUP_SETTING_PIID, value)
    if ok then
        device:emit_event(cupControl.cupSetting({value = cup}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local lock = command.args.childLock
    local value = ST_TO_LOCK[lock]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, LOCK_SIID, LOCK_PIID, value)
    if ok then
        device:emit_event(lockControl.childLock({value = lock}))
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
    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = 85, unit = "C"}))
    device:emit_event(operatingStatus.operatingStatus({value = "idle"}))
    device:emit_event(waterModeControl.waterMode({value = "roomTemperature"}))
    device:emit_event(cupControl.cupSetting({value = "middle"}))
    device:emit_event(faultStatus.deviceFault({value = "noFaults"}))
    device:emit_event(tdsInStatus.tdsIn({value = 0, unit = "ppm"}))
    device:emit_event(tdsOutStatus.tdsOut({value = 0, unit = "ppm"}))
    device:emit_event(filterOneStatus.filterLifeLevel({value = 100, unit = "%"}))
    device:emit_event(filterTwoStatus.filterLifeLevel({value = 100, unit = "%"}))
    device:emit_event(lockControl.childLock({value = "open"}))
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

local driver = Driver("miot-xiaomi-water-dispenser-a1en", {
    discovery = discovery.handle_discovery,
    lifecycle_handlers = {
        added = device_added,
        init = device_init,
        removed = device_removed,
        infoChanged = device_info_changed
    },
    capability_handlers = {
        [capabilities.thermostatHeatingSetpoint.ID] = {
            [capabilities.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] = set_heating_setpoint_handler
        },
        [waterModeControl.ID] = {
            [waterModeControl.commands.setWaterMode.NAME] = set_water_mode_handler
        },
        [cupControl.ID] = {
            [cupControl.commands.setCupSetting.NAME] = set_cup_setting_handler
        },
        [lockControl.ID] = {
            [lockControl.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
