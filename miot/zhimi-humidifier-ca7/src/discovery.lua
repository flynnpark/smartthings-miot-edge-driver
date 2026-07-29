local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-zhimi-ca7-" .. os.time(),
        label = "Zhimi Humidifier CA7",
        profile = "zhimi-humidifier-ca7",
        manufacturer = "Zhimi",
        model = "zhimi.humidifier.ca7",
        vendor_provided_label = "Zhimi Humidifier CA7",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
