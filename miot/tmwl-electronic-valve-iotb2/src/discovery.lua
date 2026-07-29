local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-valve-tmwl-iotb2-" .. os.time(),
        label = "TMWL Electronic Valve IOTB2",
        profile = "tmwl-electronic-valve-iotb2",
        manufacturer = "TMWL",
        model = "tmwl.valve.iotb2",
        vendor_provided_label = "TMWL Electronic Valve IOTB2",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
