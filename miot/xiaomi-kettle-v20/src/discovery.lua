local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-kettle-xiaomi-v20-" .. os.time(),
        label = "Xiaomi Kettle V20",
        profile = "xiaomi-kettle-v20",
        manufacturer = "Xiaomi",
        model = "xiaomi.kettle.v20",
        vendor_provided_label = "Xiaomi Kettle V20"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
