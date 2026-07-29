local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-water-heater-xiaomi-ym03-" .. os.time(),
        label = "Xiaomi Water Heater YM03",
        profile = "xiaomi-water-heater-ym03",
        manufacturer = "Xiaomi",
        model = "xiaomi.waterheater.ym03",
        vendor_provided_label = "Xiaomi Water Heater YM03",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
