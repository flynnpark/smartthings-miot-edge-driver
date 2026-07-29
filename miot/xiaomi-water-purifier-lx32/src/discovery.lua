local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-waterpuri-xiaomi-lx32-" .. os.time(),
        label = "Xiaomi Water Purifier LX32",
        profile = "xiaomi-water-purifier-lx32",
        manufacturer = "Xiaomi",
        model = "xiaomi.waterpuri.lx32",
        vendor_provided_label = "Xiaomi Water Purifier LX32"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
