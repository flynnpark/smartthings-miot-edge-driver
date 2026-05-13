local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-va5-" .. os.time(),
        label = "Mijia Smart Air Purifier 5 Pro",
        profile = "xiaomi-air-purifier-va5",
        manufacturer = "Xiaomi",
        model = "xiaomi.airp.va5",
        vendor_provided_label = "Mijia Smart Air Purifier 5 Pro",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
