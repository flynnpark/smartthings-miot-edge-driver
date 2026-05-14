local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-xiaomi-airmx-" .. os.time(),
        label = "Mijia Mist-Free Humidifier 3 Pro",
        profile = "xiaomi-humidifier-airmx",
        manufacturer = "Xiaomi",
        model = "xiaomi.humidifier.airmx",
        vendor_provided_label = "Mijia Mist-Free Humidifier 3 Pro",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
