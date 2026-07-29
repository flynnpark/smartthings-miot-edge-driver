-- Brains Occupancy Sensor R4 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local occupancyStatus = capabilities["concertmirror08464.brainsOccupyR4Status"]
local distanceStatus = capabilities["concertmirror08464.brainsOccupyR4Distance"]
local noOneTimeControl = capabilities["concertmirror08464.brainsOccupyR4NoOneTime"]
local indicatorLightControl = capabilities["concertmirror08464.brainsOccupyR4IndicatorLight"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "brains-occupancy-sensor-r4"

-- MIoT model: brains.sensor_occupy.r4
-- specModel: brains-r4
-- URN: urn:miot-spec-v2:device:occupancy-sensor:0000A0BF:brains-r4:2
--
-- Occupancy Sensor service (siid=2)
--   piid=1 occupancy-status, uint8, R enum: 0=noOne, 1=moveless, 2=inMovement, 3=enter
--   piid=2 no-one-determine-time, uint16, RW range 0..3600 seconds
--   piid=5 illumination, uint16, R, 0..10000 lux
-- Indicator Light service (siid=3)
--   piid=1 on, bool, RW
-- Customized Service For Ble (siid=5): vendor debug values, not exposed
-- custom-service (siid=6)
--   piid=16 target-distance, float, R, 0..4.5 m
--   other properties are radar tuning, breaker linkage, and engineering values,
--   not exposed

local OCCUPANCY_SIID = 2
local OCCUPANCY_STATUS_PIID = 1
local NO_ONE_TIME_PIID = 2
local ILLUMINATION_PIID = 5

local INDICATOR_SIID = 3
local INDICATOR_ON_PIID = 1

local CUSTOM_SIID = 6
local TARGET_DISTANCE_PIID = 16

-- MIoT -> SmartThings
local OCCUPANCY_TO_ST = {
    [0] = "noOne",
    [1] = "moveless",
    [2] = "inMovement",
    [3] = "enter"
}

local NO_ONE_TIME_MIN = 0
local NO_ONE_TIME_MAX = 3600

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
        {siid = OCCUPANCY_SIID, piid = OCCUPANCY_STATUS_PIID},
        {siid = OCCUPANCY_SIID, piid = NO_ONE_TIME_PIID},
        {siid = OCCUPANCY_SIID, piid = ILLUMINATION_PIID},
        {siid = INDICATOR_SIID, piid = INDICATOR_ON_PIID},
        {siid = CUSTOM_SIID, piid = TARGET_DISTANCE_PIID}
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

            if siid == OCCUPANCY_SIID then
                if piid == OCCUPANCY_STATUS_PIID then
                    local status = OCCUPANCY_TO_ST[value]
                    if status then
                        device:emit_event(occupancyStatus.occupancyStatus({value = status}))
                        -- Any detected state other than noOne counts as present.
                        if status == "noOne" then
                            device:emit_event(capabilities.presenceSensor.presence.not_present())
                        else
                            device:emit_event(capabilities.presenceSensor.presence.present())
                        end
                    end
                elseif piid == NO_ONE_TIME_PIID then
                    device:emit_event(noOneTimeControl.noOneDetermineTime({value = value, unit = "s"}))
                elseif piid == ILLUMINATION_PIID then
                    device:emit_event(capabilities.illuminanceMeasurement.illuminance({value = value, unit = "lux"}))
                end
            elseif siid == INDICATOR_SIID and piid == INDICATOR_ON_PIID then
                device:emit_event(indicatorLightControl.indicatorLight({value = value and "on" or "off"}))
            elseif siid == CUSTOM_SIID and piid == TARGET_DISTANCE_PIID then
                device:emit_event(distanceStatus.targetDistance({value = value, unit = "m"}))
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

local function set_no_one_time_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local requested = tonumber(command.args.seconds)
    if not requested then return end
    if requested < NO_ONE_TIME_MIN or requested > NO_ONE_TIME_MAX then return end

    local value = math.floor(requested)
    local ok = pcall(miot.set, device, ip, token, OCCUPANCY_SIID, NO_ONE_TIME_PIID, value)
    if ok then
        device:emit_event(noOneTimeControl.noOneDetermineTime({value = value, unit = "s"}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator = command.args.indicatorLight
    local ok = pcall(miot.set, device, ip, token, INDICATOR_SIID, INDICATOR_ON_PIID, indicator == "on")
    if ok then
        device:emit_event(indicatorLightControl.indicatorLight({value = indicator}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(occupancyStatus.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.presenceSensor.presence.not_present())
    device:emit_event(capabilities.illuminanceMeasurement.illuminance({value = 0, unit = "lux"}))
    device:emit_event(occupancyStatus.occupancyStatus({value = "noOne"}))
    device:emit_event(distanceStatus.targetDistance({value = 0, unit = "m"}))
    device:emit_event(noOneTimeControl.noOneDetermineTime({value = 30, unit = "s"}))
    device:emit_event(indicatorLightControl.indicatorLight({value = "on"}))
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

local driver = Driver("miot-brains-occupancy-sensor-r4", {
    discovery = discovery.handle_discovery,
    lifecycle_handlers = {
        added = device_added,
        init = device_init,
        removed = device_removed,
        infoChanged = device_info_changed
    },
    capability_handlers = {
        [noOneTimeControl.ID] = {
            [noOneTimeControl.commands.setNoOneDetermineTime.NAME] = set_no_one_time_handler
        },
        [indicatorLightControl.ID] = {
            [indicatorLightControl.commands.setIndicatorLight.NAME] = set_indicator_light_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
