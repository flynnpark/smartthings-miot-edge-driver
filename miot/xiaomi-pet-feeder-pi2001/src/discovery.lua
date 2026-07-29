local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-pet-feeder-xiaomi-pi2001-" .. os.time(),
        label = "Xiaomi Pet Feeder PI2001",
        profile = "xiaomi-pet-feeder-pi2001",
        manufacturer = "Xiaomi",
        model = "xiaomi.feeder.pi2001",
        vendor_provided_label = "Xiaomi Pet Feeder PI2001",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery

