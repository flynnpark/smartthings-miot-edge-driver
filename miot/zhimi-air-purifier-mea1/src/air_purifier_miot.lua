local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local miot = require "miot"

local air_purifier_miot = {}

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token
    if ip and ip ~= "" and token and #token == 32 and token:match("^[0-9a-fA-F]+$") then
        return ip, token
    end
    return nil, nil
end

local function property_key(siid, piid)
    return string.format("%d:%d", siid, piid)
end

local function custom_capability(property)
    return capabilities[property.capability]
end

local function supports_custom_property(device, property)
    return not property.capability or device:supports_capability_by_id(property.capability, "main")
end

local function to_smartthings_value(property, value)
    if property.kind == "boolean" then
        return value and "on" or "off"
    end
    if property.to_st then
        return property.to_st[value]
    end
    return value
end

local function to_miot_value(property, value)
    if property.kind == "boolean" then
        return value == "on"
    end
    if property.from_st then
        return property.from_st[value]
    end
    if property.kind == "number" then
        return tonumber(value)
    end
    return value
end

local function emit_custom_property(device, property, value)
    if not supports_custom_property(device, property) then
        return
    end

    local st_value = to_smartthings_value(property, value)
    if st_value == nil then
        return
    end

    local capability = custom_capability(property)
    device:emit_event(capability[property.attribute]({value = st_value}))
end

local function emit_standard_property(device, property, value)
    if property.kind == "power" then
        device:emit_event(value and capabilities.switch.switch.on() or capabilities.switch.switch.off())
    elseif property.kind == "humidity" then
        device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
    elseif property.kind == "temperature" then
        device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
    elseif property.kind == "pm25" and property.use_dust_sensor then
        device:emit_event(capabilities.dustSensor.fineDustLevel(math.floor(value)))
    elseif property.kind == "pm25" then
        device:emit_event(capabilities.fineDustSensor.fineDustLevel(math.floor(value)))
    elseif property.kind == "pm10" then
        device:emit_event(capabilities.dustSensor.dustLevel(math.floor(value)))
    elseif property.kind == "co2" then
        device:emit_event(capabilities.carbonDioxideMeasurement.carbonDioxide(value))
    elseif property.kind == "tvoc" then
        device:emit_event(capabilities.tvocMeasurement.tvocLevel({value = value, unit = property.unit}))
    elseif property.kind == "formaldehyde" then
        local measurement = {value = value, unit = "mg/m^3"}
        device:emit_event(capabilities.formaldehydeMeasurement.formaldehydeLevel(measurement))
    elseif property.kind == "filter" then
        device:emit_event(capabilities.filterState.filterLifeRemaining({value = value, unit = "%"}))
    end
end

local function emit_property(device, property, value)
    if property.capability then
        emit_custom_property(device, property, value)
    else
        emit_standard_property(device, property, value)
    end
end

local function schedule_refresh(device, poll_device_status)
    device.thread:call_with_delay(1, function()
        pcall(poll_device_status, device)
    end)
end

function air_purifier_miot.run(config)
    local properties = config.properties
    local properties_by_key = {}
    local poll_request = {}

    for _, property in ipairs(properties) do
        properties_by_key[property_key(property.siid, property.piid)] = property
        table.insert(poll_request, {siid = property.siid, piid = property.piid})
    end

    local function poll_device_status(device)
        local ip, token = get_device_config(device)
        if not ip then
            return
        end

        local ok, response = pcall(miot.gets, device, ip, token, poll_request)
        if not ok or not response or not response.result then
            return
        end

        for _, result in ipairs(response.result) do
            if result.code == 0 then
                local property = properties_by_key[property_key(result.siid, result.piid)]
                if property then
                    emit_property(device, property, result.value)
                end
            end
        end
    end

    local function start_polling_timer(device)
        local old_timer = device:get_field(POLLING_TIMER)
        if old_timer then
            device.thread:cancel_timer(old_timer)
        end

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

    local function write_property(device, property, value)
        local ip, token = get_device_config(device)
        if not ip then
            return
        end

        local miot_value = to_miot_value(property, value)
        if miot_value == nil then
            return
        end

        local ok = pcall(miot.set, device, ip, token, property.siid, property.piid, miot_value)
        if ok then
            emit_property(device, property, miot_value)
            schedule_refresh(device, poll_device_status)
        end
    end

    local power_property
    for _, property in ipairs(properties) do
        if property.kind == "power" then
            power_property = property
            break
        end
    end

    local function switch_on_handler(_, device)
        write_property(device, power_property, true)
    end

    local function switch_off_handler(_, device)
        write_property(device, power_property, false)
    end

    local function refresh_handler(_, device)
        pcall(poll_device_status, device)
    end

    local function ensure_profile(device)
        if config.expected_capability and
            not device:supports_capability_by_id(config.expected_capability, "main") then
            device:try_update_metadata({profile = config.profile_name})
        end
    end

    local function emit_initial_events(device)
        for _, property in ipairs(properties) do
            if property.initial ~= nil then
                emit_property(device, property, property.initial)
            end
        end
    end

    local function device_added(_, device)
        ensure_profile(device)
        device:online()
        emit_initial_events(device)
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
            config.discovery.create_device(driver)
        end

        if old.ipAddress ~= new.ipAddress or old.token ~= new.token or
            old.pollingInterval ~= new.pollingInterval then
            stop_polling_timer(device)
            local ip = get_device_config(device)
            if ip then
                start_polling_timer(device)
                pcall(poll_device_status, device)
            end
        end
    end

    local capability_handlers = {
        [capabilities.switch.ID] = {
            [capabilities.switch.commands.on.NAME] = switch_on_handler,
            [capabilities.switch.commands.off.NAME] = switch_off_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }

    for _, property in ipairs(properties) do
        if property.capability and property.command then
            local capability = custom_capability(property)
            capability_handlers[capability.ID] = {
                [capability.commands[property.command].NAME] = function(_, device, command)
                    write_property(device, property, command.args[property.argument])
                end
            }
        end
    end

    local driver = Driver(config.driver_name, {
        discovery = config.discovery.handle_discovery,
        lifecycle_handlers = {
            added = device_added,
            init = device_init,
            removed = device_removed,
            infoChanged = device_info_changed
        },
        capability_handlers = capability_handlers
    })

    driver:run()
end

return air_purifier_miot
