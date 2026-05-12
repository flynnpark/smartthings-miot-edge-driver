local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p33-" .. os.time(),
        label = "Xiaomi Smart Standing Fan 2 Pro",
        profile = "dmaker-fan-p33",
        manufacturer = "Xiaomi",
        model = "dmaker.fan.p33",
        vendor_provided_label = "Xiaomi Smart Standing Fan 2 Pro",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
