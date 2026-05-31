local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miio-light-yeelink-mono1-" .. os.time(),
        label = "Yeelight Mono Bulb",
        profile = "yeelink-light-mono1",
        manufacturer = "Yeelight",
        model = "yeelink.light.mono1",
        vendor_provided_label = "Yeelight Mono Bulb",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
