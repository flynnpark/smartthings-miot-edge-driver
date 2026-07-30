local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miio-deerma-jsq-" .. os.time(),
        label = "Mi Smart Antibacterial Humidifier",
        profile = "deerma-humidifier-jsq",
        manufacturer = "Deerma",
        model = "deerma.humidifier.jsq",
        vendor_provided_label = "Mi Smart Antibacterial Humidifier"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
