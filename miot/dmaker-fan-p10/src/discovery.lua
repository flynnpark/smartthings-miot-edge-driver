local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p10-" .. os.time(),
        label = "Xiaomi Fan P10",
        profile = "dmaker-fan-p10",
        manufacturer = "Xiaomi",
        model = "dmaker.fan.p10",
        vendor_provided_label = "Xiaomi Fan P10",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
