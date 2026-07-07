local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-xiaomi-p30-" .. os.time(),
        label = "Mi Smart Standing Fan 2",
        profile = "xiaomi-fan-p30",
        manufacturer = "Xiaomi",
        model = "xiaomi.fan.p30",
        vendor_provided_label = "Mi Smart Standing Fan 2",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
