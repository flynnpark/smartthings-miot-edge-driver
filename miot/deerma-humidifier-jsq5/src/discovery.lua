local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-deerma-jsq5-" .. os.time(),
        label = "Deerma Humidifier JSQ5",
        profile = "deerma-humidifier-jsq5",
        manufacturer = "Deerma",
        model = "deerma.humidifier.jsq5",
        vendor_provided_label = "Deerma Humidifier JSQ5",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
