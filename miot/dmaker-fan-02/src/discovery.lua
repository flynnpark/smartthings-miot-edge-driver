local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-dmaker-02-" .. os.time(),
        label = "Dream Maker Feel Fan Plus",
        profile = "dmaker-fan-02",
        manufacturer = "Xiaomi",
        model = "dmaker.fan.02",
        vendor_provided_label = "Dream Maker Feel Fan Plus",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
