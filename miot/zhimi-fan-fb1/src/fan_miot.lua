local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local miot = require "miot"

-- Shared driver body for native MIoT fans. It mirrors air_purifier_miot but
-- adds the two shapes fans need: angle values that travel as strings so the
-- iOS app renders them, and the standard fanSpeedPercent slider.
local fan_miot = {}

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

local function clamp(value, minimum, maximum)
    if minimum and value < minimum then
        return minimum
    end
    if maximum and value > maximum then
        return maximum
    end
    return value
end

local function to_smartthings_value(property, value)
    if property.kind == "boolean" then
        return value and "on" or "off"
    end
    if property.kind == "angle" then
        if type(value) ~= "number" then
            return nil
        end
        return tostring(math.floor(value))
    end
    if property.to_st then
        return property.to_st[value]
    end
    return value
end

local function to_miot_value(property, value)
    if property.kind == "boolean" or property.kind == "oscillation" then
        return value == "on"
    end
    if property.kind == "angle" then
        local number = tonumber(value)
        if not number then
            return nil
        end
        number = math.floor(number)
        if property.step and property.step > 1 then
            local minimum = property.minimum or 0
            number = minimum + math.floor((number - minimum) / property.step + 0.5) * property.step
        end
        return clamp(number, property.minimum, property.maximum)
    end
    if property.from_st then
        return property.from_st[value]
    end
    if property.kind == "number" or property.kind == "fan_speed" then
        local number = tonumber(value)
        if not number then
            return nil
        end
        return clamp(math.floor(number), property.minimum, property.maximum)
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
    elseif property.kind == "fan_speed" then
        device:emit_event(capabilities.fanSpeedPercent.percent(math.floor(value)))
    elseif property.kind == "oscillation" then
        local mode = value and "horizontal" or "off"
        device:emit_event(capabilities.fanOscillationMode.fanOscillationMode(mode))
    elseif property.kind == "humidity" then
        device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
    elseif property.kind == "temperature" then
        device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
    end
end

local function emit_property(device, property, value)
    if property.capability then
        emit_custom_property(device, property, value)
    else
        emit_standard_property(device, property, value)
    end
end

function fan_miot.run(config)
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
            device.thread:call_with_delay(1, function()
                pcall(poll_device_status, device)
            end)
        end
    end

    local power_property
    local speed_property
    local oscillation_property
    for _, property in ipairs(properties) do
        if property.kind == "power" then
            power_property = property
        elseif property.kind == "fan_speed" then
            speed_property = property
        elseif property.kind == "oscillation" then
            oscillation_property = property
        end
    end

    local function ensure_profile(device)
        if config.expected_capability and
            not device:supports_capability_by_id(config.expected_capability, "main") then
            device:try_update_metadata({profile = config.profile_name})
        end
    end

    local function emit_initial_events(device)
        if oscillation_property then
            local modes = {"off", "horizontal"}
            device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes(modes))
        end
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

        -- Re-publish the oscillation list so the app keeps the options.
        if oscillation_property then
            local modes = {"off", "horizontal"}
            device:emit_event(capabilities.fanOscillationMode.supportedFanOscillationModes(modes))
        end

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
            [capabilities.switch.commands.on.NAME] = function(_, device)
                write_property(device, power_property, true)
            end,
            [capabilities.switch.commands.off.NAME] = function(_, device)
                write_property(device, power_property, false)
            end
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = function(_, device)
                pcall(poll_device_status, device)
            end
        }
    }

    if speed_property then
        capability_handlers[capabilities.fanSpeedPercent.ID] = {
            [capabilities.fanSpeedPercent.commands.setPercent.NAME] = function(_, device, command)
                write_property(device, speed_property, command.args.percent)
            end
        }
    end

    if oscillation_property then
        capability_handlers[capabilities.fanOscillationMode.ID] = {
            [capabilities.fanOscillationMode.commands.setFanOscillationMode.NAME] = function(_, device, command)
                write_property(device, oscillation_property, command.args.fanOscillationMode == "horizontal" and "on" or "off")
            end
        }
    end

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

return fan_miot
