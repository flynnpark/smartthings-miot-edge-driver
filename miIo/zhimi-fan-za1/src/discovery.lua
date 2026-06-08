local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miio-fan-zhimi-za1-" .. os.time(),
        label = "Zhimi Fan ZA1",
        profile = "zhimi-fan-za1",
        manufacturer = "Smartmi",
        model = "zhimi.fan.za1",
        vendor_provided_label = "Smartmi Inverter Pedestal Fan",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
