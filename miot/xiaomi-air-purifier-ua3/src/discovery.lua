local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-xiaomi-ua3-" .. os.time(),
        label = "Xiaomi Air Purifier UA3",
        profile = "xiaomi-air-purifier-ua3",
        manufacturer = "Xiaomi",
        model = "xiaomi.airp.ua3",
        vendor_provided_label = "Xiaomi Air Purifier UA3"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
