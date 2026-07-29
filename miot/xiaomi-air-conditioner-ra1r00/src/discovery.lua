local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-aircon-xiaomi-ra1r00-" .. os.time(),
        label = "Xiaomi Air Conditioner RA1",
        profile = "xiaomi-air-conditioner-ra1r00",
        manufacturer = "Xiaomi",
        model = "xiaomi.airc.ra1r00",
        vendor_provided_label = "Xiaomi Air Conditioner RA1",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
