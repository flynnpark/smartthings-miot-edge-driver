local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-pet-waterer-xiaomi-70m2-" .. os.time(),
        label = "Xiaomi Pet Waterer 70M2",
        profile = "xiaomi-pet-waterer-70m2",
        manufacturer = "Xiaomi",
        model = "xiaomi.pet_waterer.70m2",
        vendor_provided_label = "Xiaomi Pet Waterer 70M2",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
