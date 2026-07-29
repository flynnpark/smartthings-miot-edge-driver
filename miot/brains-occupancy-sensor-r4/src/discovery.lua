local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-occupancy-brains-r4-" .. os.time(),
        label = "Brains Occupancy Sensor R4",
        profile = "brains-occupancy-sensor-r4",
        manufacturer = "Brains",
        model = "brains.sensor_occupy.r4",
        vendor_provided_label = "Brains Occupancy Sensor R4",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
