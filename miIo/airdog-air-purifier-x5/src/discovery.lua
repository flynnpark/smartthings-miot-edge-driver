local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miio-airdog-x5-" .. os.time(),
        label = "Airdog Air Purifier X5",
        profile = "airdog-air-purifier-x5",
        manufacturer = "Airdog",
        model = "airdog.airpurifier.x5",
        vendor_provided_label = "Airdog Air Purifier X5"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
