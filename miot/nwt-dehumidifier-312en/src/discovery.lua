local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-dehumidifier-nwt-312en-" .. os.time(),
        label = "NWT Dehumidifier 312EN",
        profile = "nwt-dehumidifier-312en",
        manufacturer = "NWT",
        model = "nwt.derh.312en",
        vendor_provided_label = "NWT Dehumidifier 312EN",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
