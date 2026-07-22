local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-zhimi-vb2a-" .. os.time(),
        label = "Zhimi Air Purifier VB2A",
        profile = "zhimi-air-purifier-vb2a",
        manufacturer = "Xiaomi",
        model = "zhimi.airp.vb2a",
        vendor_provided_label = "Zhimi Air Purifier VB2A"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
