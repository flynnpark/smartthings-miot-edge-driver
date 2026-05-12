local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-xiaomi-3lite-" .. os.time(),
        label = "Xiaomi Humidifier 3lite",
        profile = "xiaomi-humidifier-3lite",
        manufacturer = "Xiaomi",
        model = "xiaomi.humidifier.3lite",
        vendor_provided_label = "Smartmi Evaporative Humidifier 3lite",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
