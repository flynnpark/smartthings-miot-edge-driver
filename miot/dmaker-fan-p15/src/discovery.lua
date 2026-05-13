local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p15-" .. os.time(),
        label = "Mi Smart Standing Fan Pro",
        profile = "dmaker-fan-p15",
        manufacturer = "Xiaomi",
        model = "dmaker.fan.p15",
        vendor_provided_label = "Mi Smart Standing Fan Pro",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
