local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p5c-" .. os.time(),
        label = "Mijia Smart DC Standing Fan 1X",
        profile = "dmaker-fan-p5c",
        manufacturer = "Dmaker",
        model = "dmaker.fan.p5c",
        vendor_provided_label = "Mijia Smart DC Standing Fan 1X",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
