local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-airdog-mn-" .. os.time(),
        label = "Airdog Air Purifier MN",
        profile = "airdog-air-purifier-mn",
        manufacturer = "Airdog",
        model = "airdog.airpurifier.mn",
        vendor_provided_label = "Airdog Air Purifier MN"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
