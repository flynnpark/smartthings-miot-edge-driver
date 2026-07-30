local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miio-airdog-x7sm-" .. os.time(),
        label = "Airdog Air Purifier X7sm",
        profile = "airdog-air-purifier-x7sm",
        manufacturer = "Airdog",
        model = "airdog.airpurifier.x7sm",
        vendor_provided_label = "Airdog Air Purifier X7sm"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
