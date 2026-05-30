local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-fan-pinlo-fs1-" .. os.time(),
        label = "Plabson Slim Fan",
        profile = "pinlo-fan-fs1",
        manufacturer = "Pinlo",
        model = "pinlo.fan.fs1",
        vendor_provided_label = "Plabson Slim Fan",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
