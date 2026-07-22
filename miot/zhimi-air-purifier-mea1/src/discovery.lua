local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-zhimi-mea1-" .. os.time(),
        label = "Zhimi Air Purifier MEA1",
        profile = "zhimi-air-purifier-mea1",
        manufacturer = "Xiaomi",
        model = "zhimi.airp.mea1",
        vendor_provided_label = "Zhimi Air Purifier MEA1"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
