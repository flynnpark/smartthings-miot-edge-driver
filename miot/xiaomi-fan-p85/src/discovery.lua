local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-xiaomi-p85-" .. os.time(),
        label = "Mijia Smart Standing Fan Pro Slim",
        profile = "xiaomi-fan-p85",
        manufacturer = "Xiaomi",
        model = "xiaomi.fan.p85",
        vendor_provided_label = "Mijia Smart Standing Fan Pro Slim",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
