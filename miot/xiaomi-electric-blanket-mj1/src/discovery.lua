local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-electric-blanket-xiaomi-mj1-" .. os.time(),
        label = "Xiaomi Electric Blanket MJ1",
        profile = "xiaomi-electric-blanket-mj1",
        manufacturer = "Xiaomi",
        model = "xiaomi.blanket.mj1",
        vendor_provided_label = "Xiaomi Electric Blanket MJ1",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
