local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-deerma-990dw-" .. os.time(),
        label = "Deerma Humidifier 990DW",
        profile = "deerma-humidifier-990dw",
        manufacturer = "Deerma",
        model = "deerma.humidifier.990dw",
        vendor_provided_label = "Deerma Humidifier 990DW",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
