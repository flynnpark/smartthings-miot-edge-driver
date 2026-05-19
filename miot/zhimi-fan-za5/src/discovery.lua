local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-zhimi-za5-" .. os.time(),
        label = "Smartmi Standing Fan 3",
        profile = "zhimi-fan-za5",
        manufacturer = "Xiaomi",
        model = "zhimi.fan.za5",
        vendor_provided_label = "Smartmi Standing Fan 3",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
