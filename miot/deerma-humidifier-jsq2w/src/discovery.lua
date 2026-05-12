local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-deerma-jsq2w-" .. os.time(),
        label = "Deerma Humidifier JSQ2W",
        profile = "deerma-humidifier-jsq2w",
        manufacturer = "Deerma",
        model = "deerma.humidifier.jsq2w",
        vendor_provided_label = "Deerma Humidifier JSQ2W",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
