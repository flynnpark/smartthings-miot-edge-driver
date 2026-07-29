local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airer-xiaomi-pro3-" .. os.time(),
        label = "Xiaomi Airer Pro 3",
        profile = "xiaomi-airer-pro3",
        manufacturer = "Xiaomi",
        model = "xiaomi.airer.pro3",
        vendor_provided_label = "Xiaomi Airer Pro 3",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
