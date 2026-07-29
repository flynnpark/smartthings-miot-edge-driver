local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-zhimi-fa1-" .. os.time(),
        label = "Zhimi Fan FA1",
        profile = "zhimi-fan-fa1",
        manufacturer = "Smartmi",
        model = "zhimi.fan.fa1",
        vendor_provided_label = "Zhimi Fan FA1"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
