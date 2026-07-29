local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-baomi-450a-" .. os.time(),
        label = "Baomi Air Purifier 450A",
        profile = "baomi-air-purifier-450a",
        manufacturer = "Baomi",
        model = "baomi.airpurifier.450a",
        vendor_provided_label = "Baomi Air Purifier 450A"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
