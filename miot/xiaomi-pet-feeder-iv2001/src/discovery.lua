local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-pet-feeder-xiaomi-iv2001-" .. os.time(),
        label = "Xiaomi Pet Feeder IV2001",
        profile = "xiaomi-pet-feeder-iv2001",
        manufacturer = "Xiaomi",
        model = "xiaomi.feeder.iv2001",
        vendor_provided_label = "Xiaomi Pet Feeder IV2001",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
