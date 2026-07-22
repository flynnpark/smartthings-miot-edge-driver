local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-zhimi-xa1-" .. os.time(),
        label = "Zhimi Air Purifier XA1",
        profile = "zhimi-air-purifier-xa1",
        manufacturer = "Xiaomi",
        model = "zhimi.airpurifier.xa1",
        vendor_provided_label = "Zhimi Air Purifier XA1"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
