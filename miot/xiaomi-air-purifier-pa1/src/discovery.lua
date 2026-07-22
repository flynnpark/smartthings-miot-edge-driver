local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-xiaomi-pa1-" .. os.time(),
        label = "Xiaomi Air Purifier PA1",
        profile = "xiaomi-air-purifier-pa1",
        manufacturer = "Xiaomi",
        model = "xiaomi.airp.pa1",
        vendor_provided_label = "Xiaomi Air Purifier PA1"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
