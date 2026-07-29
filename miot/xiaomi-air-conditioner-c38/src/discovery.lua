local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-aircon-xiaomi-c38-" .. os.time(),
        label = "Xiaomi Air Conditioner C38",
        profile = "xiaomi-air-conditioner-c38",
        manufacturer = "Xiaomi",
        model = "xiaomi.aircondition.c38",
        vendor_provided_label = "Xiaomi Air Conditioner C38",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
