local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-waterheater-xiaomi-ym02-" .. os.time(),
        label = "Xiaomi Water Heater YM02",
        profile = "xiaomi-water-heater-ym02",
        manufacturer = "Xiaomi",
        model = "xiaomi.waterheater.ym02",
        vendor_provided_label = "Xiaomi Water Heater YM02"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
