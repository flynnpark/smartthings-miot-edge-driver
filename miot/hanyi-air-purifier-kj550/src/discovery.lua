local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-hanyi-kj550-" .. os.time(),
        label = "Hanyi Air Purifier KJ550",
        profile = "hanyi-air-purifier-kj550",
        manufacturer = "Hanyi",
        model = "hanyi.airpurifier.kj550",
        vendor_provided_label = "Hanyi Air Purifier KJ550"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
