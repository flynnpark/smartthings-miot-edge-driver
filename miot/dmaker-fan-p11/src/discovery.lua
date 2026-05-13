local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p11-" .. os.time(),
        label = "Xiaomi Smart Fan V2",
        profile = "dmaker-fan-p11",
        manufacturer = "Xiaomi",
        model = "dmaker.fan.p11",
        vendor_provided_label = "Xiaomi Smart Fan V2",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
