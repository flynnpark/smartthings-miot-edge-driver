local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-xiaomi-va2b-" .. os.time(),
        label = "Xiaomi Air Purifier VA2B",
        profile = "xiaomi-air-purifier-va2b",
        manufacturer = "Xiaomi",
        model = "xiaomi.airp.va2b",
        vendor_provided_label = "Xiaomi Air Purifier VA2B"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
