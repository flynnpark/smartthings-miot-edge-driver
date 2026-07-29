local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-dmaker-swift2-" .. os.time(),
        label = "Dmaker Air Purifier Swift 2",
        profile = "dmaker-air-purifier-swift2",
        manufacturer = "Dmaker",
        model = "dmaker.airp.swift2",
        vendor_provided_label = "Dmaker Air Purifier Swift 2"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
