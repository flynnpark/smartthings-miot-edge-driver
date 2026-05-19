local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p39-" .. os.time(),
        label = "Xiaomi Smart Tower Fan",
        profile = "dmaker-fan-p39",
        manufacturer = "Xiaomi",
        model = "dmaker.fan.p39",
        vendor_provided_label = "Xiaomi Smart Tower Fan",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
