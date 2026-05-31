local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-xiaomi-600-" .. os.time(),
        label = "Xiaomi Humidifier 600",
        profile = "xiaomi-humidifier-600",
        manufacturer = "Xiaomi",
        model = "xiaomi.humidifier.600",
        vendor_provided_label = "Xiaomi Humidifier 600",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
