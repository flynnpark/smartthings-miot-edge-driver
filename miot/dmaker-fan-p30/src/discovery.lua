local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p30-" .. os.time(),
        label = "Xiaomi Fan P30",
        profile = "dmaker-fan-p30",
        manufacturer = "Dmaker",
        model = "dmaker.fan.p30",
        vendor_provided_label = "Xiaomi Fan P30",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
