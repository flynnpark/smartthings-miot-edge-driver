local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-hood-xiaomi-jyjss2-" .. os.time(),
        label = "Xiaomi Hood JYJSS2",
        profile = "xiaomi-hood-jyjss2",
        manufacturer = "Xiaomi",
        model = "xiaomi.hood.jyjss2",
        vendor_provided_label = "Xiaomi Hood JYJSS2"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
