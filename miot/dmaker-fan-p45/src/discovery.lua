local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p45-" .. os.time(),
        label = "Mijia DC Inverter Tower Fan 2",
        profile = "dmaker-fan-p45",
        manufacturer = "Xiaomi",
        model = "dmaker.fan.p45",
        vendor_provided_label = "Mijia DC Inverter Tower Fan 2",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
