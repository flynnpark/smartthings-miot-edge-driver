local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-heater-zhimi-mc2a-" .. os.time(),
        label = "Mi Smart Space Heater S MC2A",
        profile = "zhimi-heater-mc2a",
        manufacturer = "Smartmi",
        model = "zhimi.heater.mc2a",
        vendor_provided_label = "Mi Smart Space Heater S MC2A",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
