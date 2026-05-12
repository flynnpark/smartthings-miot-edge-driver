local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-xiaomi-p1200-" .. os.time(),
        label = "Xiaomi Humidifier P1200",
        profile = "xiaomi-humidifier-p1200",
        manufacturer = "Xiaomi",
        model = "xiaomi.humidifier.p1200",
        vendor_provided_label = "MIJIA Mist-Free Humidifier 3 1200",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
