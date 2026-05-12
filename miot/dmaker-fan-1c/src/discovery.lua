local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-1c-" .. os.time(),
        label = "Xiaomi Fan 1C",
        profile = "dmaker-fan-1c",
        manufacturer = "Xiaomi",
        model = "dmaker.fan.1c",
        vendor_provided_label = "Xiaomi Fan 1C",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
