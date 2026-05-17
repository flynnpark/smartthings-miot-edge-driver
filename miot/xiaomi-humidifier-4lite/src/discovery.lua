local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-xiaomi-4lite-" .. os.time(),
        label = "Xiaomi Humidifier 4lite",
        profile = "xiaomi-humidifier-4lite",
        manufacturer = "Xiaomi",
        model = "xiaomi.humidifier.4lite",
        vendor_provided_label = "Xiaomi Humidifier 4lite",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
