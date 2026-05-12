local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-ca4-" .. os.time(),
        label = "Zhimi Humidifier CA4",
        profile = "zhimi-humidifier-ca4",
        manufacturer = "Zhimi",
        model = "zhimi.humidifier.ca4",
        vendor_provided_label = "Zhimi Humidifier CA4",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
