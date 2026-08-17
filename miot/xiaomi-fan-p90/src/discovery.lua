local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-xiaomi-p90-" .. os.time(),
        label = "Mijia Smart DC Inverter Circulation Fan Pro",
        profile = "xiaomi-fan-p90",
        manufacturer = "Xiaomi",
        model = "xiaomi.fan.p90",
        vendor_provided_label = "Mijia Smart DC Inverter Circulation Fan Pro"
    })
end

function discovery.handle_discovery(driver, _, _)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
