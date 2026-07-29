local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airer-xiaomi-lyj3xs-" .. os.time(),
        label = "Xiaomi Airer LYJ3XS",
        profile = "xiaomi-airer-lyj3xs",
        manufacturer = "Xiaomi",
        model = "xiaomi.airer.lyj3xs",
        vendor_provided_label = "Xiaomi Airer LYJ3XS"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
