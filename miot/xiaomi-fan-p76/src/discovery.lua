local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-xiaomi-p76-" .. os.time(),
        label = "Xiaomi Fan P76",
        profile = "xiaomi-fan-p76",
        manufacturer = "Xiaomi",
        model = "xiaomi.fan.p76",
        vendor_provided_label = "Xiaomi Fan P76",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
