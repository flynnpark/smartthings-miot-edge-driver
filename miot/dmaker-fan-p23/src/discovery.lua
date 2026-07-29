local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p23-" .. os.time(),
        label = "Mijia Fan P23",
        profile = "dmaker-fan-p23",
        manufacturer = "Dmaker",
        model = "dmaker.fan.p23",
        vendor_provided_label = "Mijia Fan P23"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
