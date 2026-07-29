local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-humidifier-pinlo-sh01-" .. os.time(),
        label = "Pinlo Humidifier SH01",
        profile = "pinlo-humidifier-sh01",
        manufacturer = "Pinlo",
        model = "pinlo.humidifier.sh01",
        vendor_provided_label = "Pinlo Humidifier SH01",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
