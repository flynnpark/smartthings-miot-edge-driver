local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-dmaker-p2-" .. os.time(),
        label = "Dmaker Humidifier P2",
        profile = "dmaker-humidifier-p2",
        manufacturer = "Xiaomi",
        model = "dmaker.humidifier.p2",
        vendor_provided_label = "Dmaker Humidifier P2",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
