local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-xiaomi-va3-" .. os.time(),
        label = "Xiaomi Air Purifier VA3",
        profile = "xiaomi-air-purifier-va3",
        manufacturer = "Xiaomi",
        model = "xiaomi.airp.va3",
        vendor_provided_label = "Xiaomi Air Purifier VA3"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
