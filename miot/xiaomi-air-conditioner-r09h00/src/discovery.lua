local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-aircon-xiaomi-r09h00-" .. os.time(),
        label = "Xiaomi Air Conditioner R09",
        profile = "xiaomi-air-conditioner-r09h00",
        manufacturer = "Xiaomi",
        model = "xiaomi.airc.r09h00",
        vendor_provided_label = "Xiaomi Air Conditioner R09",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
