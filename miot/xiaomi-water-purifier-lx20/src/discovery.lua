local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-water-purifier-xiaomi-lx20-" .. os.time(),
        label = "Xiaomi Water Purifier LX20",
        profile = "xiaomi-water-purifier-lx20",
        manufacturer = "Xiaomi",
        model = "xiaomi.waterpuri.lx20",
        vendor_provided_label = "Xiaomi Water Purifier LX20",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
