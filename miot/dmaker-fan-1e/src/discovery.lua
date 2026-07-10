local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-1e-" .. os.time(),
        label = "Mijia DC Inverter Standing Fan E",
        profile = "dmaker-fan-1e",
        manufacturer = "Xiaomi",
        model = "dmaker.fan.1e",
        vendor_provided_label = "Mijia DC Inverter Standing Fan E",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
