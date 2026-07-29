local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-dehumidifier-nwt-24wu1-" .. os.time(),
        label = "NWT Dehumidifier 24WU1",
        profile = "nwt-dehumidifier-24wu1",
        manufacturer = "NWT",
        model = "nwt.derh.24wu1",
        vendor_provided_label = "NWT Dehumidifier 24WU1",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
