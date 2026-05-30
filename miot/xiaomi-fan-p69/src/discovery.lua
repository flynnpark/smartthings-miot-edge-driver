local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-xiaomi-p69-" .. os.time(),
        label = "Mijia Smart Desktop Air Circulation Fan",
        profile = "xiaomi-fan-p69",
        manufacturer = "Xiaomi",
        model = "xiaomi.fan.p69",
        vendor_provided_label = "Mijia Smart Desktop Air Circulation Fan",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
