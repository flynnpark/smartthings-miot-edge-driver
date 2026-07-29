local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-viomi-v3-" .. os.time(),
        label = "Viomi Air Purifier V3",
        profile = "viomi-air-purifier-v3",
        manufacturer = "Viomi",
        model = "viomi.airp.v3",
        vendor_provided_label = "Viomi Air Purifier V3"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
