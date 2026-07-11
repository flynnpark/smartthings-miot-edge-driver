local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p44-" .. os.time(),
        label = "Mijia Smart Evaporative Cooling Fan",
        profile = "dmaker-fan-p44",
        manufacturer = "Xiaomi",
        model = "dmaker.fan.p44",
        vendor_provided_label = "Mijia Smart Evaporative Cooling Fan",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
