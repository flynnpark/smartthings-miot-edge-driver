local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miio-fan-zhimi-za3-" .. os.time(),
        label = "Zhimi Fan ZA3",
        profile = "zhimi-fan-za3",
        manufacturer = "Smartmi",
        model = "zhimi.fan.za3",
        vendor_provided_label = "Smartmi Pedestal Fan ZA3",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
