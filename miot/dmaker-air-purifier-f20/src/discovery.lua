local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-dmaker-f20-" .. os.time(),
        label = "Dmaker Air Purifier F20",
        profile = "dmaker-air-purifier-f20",
        manufacturer = "Dmaker",
        model = "dmaker.airpurifier.f20",
        vendor_provided_label = "Dmaker Air Purifier F20"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
