local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-xiaomi-va4-" .. os.time(),
        label = "Xiaomi Air Purifier VA4",
        profile = "xiaomi-air-purifier-va4",
        manufacturer = "Xiaomi",
        model = "xiaomi.airp.va4",
        vendor_provided_label = "Xiaomi Air Purifier VA4"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
