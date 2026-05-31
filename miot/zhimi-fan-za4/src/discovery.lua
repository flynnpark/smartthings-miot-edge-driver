local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-zhimi-za4-" .. os.time(),
        label = "Smartmi Standing Fan 2S",
        profile = "zhimi-fan-za4",
        manufacturer = "Smartmi",
        model = "zhimi.fan.za4",
        vendor_provided_label = "Smartmi Standing Fan 2S",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
