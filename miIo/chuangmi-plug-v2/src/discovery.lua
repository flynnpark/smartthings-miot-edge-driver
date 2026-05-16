local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miio-chuangmi-plug-v2-" .. os.time(),
        label = "Xiaomi Smart WiFi Socket",
        profile = "chuangmi-plug-v2",
        manufacturer = "Chuangmi",
        model = "chuangmi.plug.v2",
        vendor_provided_label = "Xiaomi Smart WiFi Socket",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
