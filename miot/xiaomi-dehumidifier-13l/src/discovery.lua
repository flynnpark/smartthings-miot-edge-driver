local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-dehumidifier-xiaomi-13l-" .. os.time(),
        label = "Xiaomi Dehumidifier 13L",
        profile = "xiaomi-dehumidifier-13l",
        manufacturer = "Xiaomi",
        model = "xiaomi.derh.13l",
        vendor_provided_label = "Mijia Smart Dehumidifier 13L",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
