local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-zhimi-ua1-" .. os.time(),
        label = "Zhimi Air Purifier UA1",
        profile = "zhimi-air-purifier-ua1",
        manufacturer = "Xiaomi",
        model = "zhimi.airp.ua1",
        vendor_provided_label = "Zhimi Air Purifier UA1"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
