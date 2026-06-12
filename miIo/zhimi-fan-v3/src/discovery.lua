local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miio-fan-zhimi-v3-" .. os.time(),
        label = "Smartmi Smart Wireless Fan 1st Gen",
        profile = "zhimi-fan-v3",
        manufacturer = "Zhimi",
        model = "zhimi.fan.v3",
        vendor_provided_label = "Smartmi Smart Wireless Fan 1st Gen"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
