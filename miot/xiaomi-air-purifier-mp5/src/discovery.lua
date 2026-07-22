local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-xiaomi-mp5-" .. os.time(),
        label = "Xiaomi Air Purifier MP5",
        profile = "xiaomi-air-purifier-mp5",
        manufacturer = "Xiaomi",
        model = "xiaomi.airp.mp5",
        vendor_provided_label = "Xiaomi Air Purifier MP5"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
