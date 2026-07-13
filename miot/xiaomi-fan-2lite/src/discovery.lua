local discovery = {}

function discovery.create_device(driver)
    local metadata = {
        type = "LAN",
        device_network_id = "miot-fan-xiaomi-2lite-" .. os.time(),
        label = "Mi Smart Standing Fan 2 Lite",
        profile = "xiaomi-fan-2lite",
        manufacturer = "Xiaomi",
        model = "xiaomi.fan.2lite",
        vendor_provided_label = "Mi Smart Standing Fan 2 Lite"
    }

    driver:try_create_device(metadata)
end

function discovery.handle_discovery(driver, _, _)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
