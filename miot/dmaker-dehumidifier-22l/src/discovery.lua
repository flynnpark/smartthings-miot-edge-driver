local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-dehumidifier-dmaker-22l-" .. os.time(),
        label = "Mijia Dehumidifier 22L",
        profile = "dmaker-dehumidifier-22l",
        manufacturer = "Xiaomi",
        model = "dmaker.derh.22l",
        vendor_provided_label = "Mijia Smart Dehumidifier 22L",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
