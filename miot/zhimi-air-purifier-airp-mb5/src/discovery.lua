local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-airp-mb5-" .. os.time(),
        label = "Xiaomi Smart Air Purifier 4",
        profile = "zhimi-airp-mb5",
        manufacturer = "Xiaomi",
        model = "zhimi.airp.mb5",
        vendor_provided_label = "Xiaomi Smart Air Purifier 4",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
