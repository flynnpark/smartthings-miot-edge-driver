local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-dehumidifier-nwt-16l-" .. os.time(),
        label = "NWT Dehumidifier 16L",
        profile = "nwt-dehumidifier-16l",
        manufacturer = "NWT",
        model = "nwt.fan.16l",
        vendor_provided_label = "NWT Dehumidifier 16L",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
