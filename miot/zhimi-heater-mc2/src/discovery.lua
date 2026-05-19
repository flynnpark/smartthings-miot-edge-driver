local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-heater-zhimi-mc2-" .. os.time(),
        label = "Mi Smart Space Heater S",
        profile = "zhimi-heater-mc2",
        manufacturer = "Smartmi",
        model = "zhimi.heater.mc2",
        vendor_provided_label = "Mi Smart Space Heater S",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery

