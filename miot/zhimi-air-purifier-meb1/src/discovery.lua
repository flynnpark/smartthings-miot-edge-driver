local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-meb1-" .. os.time(),
        label = "Xiaomi Smart Air Purifier Elite",
        profile = "zhimi-air-purifier-meb1",
        manufacturer = "Xiaomi",
        model = "zhimi.airp.meb1",
        vendor_provided_label = "Xiaomi Smart Air Purifier Elite",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
