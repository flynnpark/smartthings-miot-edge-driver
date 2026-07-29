local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-pet-waterer-xiaomi-iv02-" .. os.time(),
        label = "Xiaomi Pet Waterer IV02",
        profile = "xiaomi-pet-waterer-iv02",
        manufacturer = "Xiaomi",
        model = "xiaomi.pet_waterer.iv02",
        vendor_provided_label = "Xiaomi Pet Waterer IV02",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
