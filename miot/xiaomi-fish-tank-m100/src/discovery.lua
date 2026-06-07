local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fish-tank-hfjh-m100-" .. os.time(),
        label = "Xiaomi Smart Fish Tank MYG100",
        profile = "xiaomi-fish-tank-m100",
        manufacturer = "Xiaomi",
        model = "hfjh.fishbowl.m100",
        vendor_provided_label = "Xiaomi Smart Fish Tank MYG100",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
