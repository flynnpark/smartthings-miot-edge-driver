local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-hood-xiaomi-ymv5-" .. os.time(),
        label = "Xiaomi Hood YMV5",
        profile = "xiaomi-hood-ymv5",
        manufacturer = "Xiaomi",
        model = "xiaomi.hood.ymv5",
        vendor_provided_label = "Xiaomi Hood YMV5",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
