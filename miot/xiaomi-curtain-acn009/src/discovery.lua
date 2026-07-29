local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-curtain-xiaomi-acn009-" .. os.time(),
        label = "Xiaomi Curtain ACN009",
        profile = "xiaomi-curtain-acn009",
        manufacturer = "Xiaomi",
        model = "xiaomi.curtain.acn009",
        vendor_provided_label = "Xiaomi Curtain ACN009",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
