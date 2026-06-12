local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fish-tank-xiaomi-m200-" .. os.time(),
        label = "Xiaomi Smart Fishbowl M200",
        profile = "xiaomi-fish-tank-m200",
        manufacturer = "Xiaomi",
        model = "xiaomi.fishbowl.m200",
        vendor_provided_label = "Xiaomi Smart Fishbowl M200",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
