local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-zhimi-sa4-" .. os.time(),
        label = "Zhimi Air Purifier SA4",
        profile = "zhimi-air-purifier-sa4",
        manufacturer = "Xiaomi",
        model = "zhimi.airp.sa4",
        vendor_provided_label = "Zhimi Air Purifier SA4"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
