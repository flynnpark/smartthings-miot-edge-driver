local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-water-dispenser-xiaomi-a1en-" .. os.time(),
        label = "Xiaomi Water Dispenser A1EN",
        profile = "xiaomi-water-dispenser-a1en",
        manufacturer = "Xiaomi",
        model = "xiaomi.ysj.a1en",
        vendor_provided_label = "Xiaomi Water Dispenser A1EN",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
