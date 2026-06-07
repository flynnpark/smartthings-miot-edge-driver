local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miio-light-yeelink-color2-" .. os.time(),
        label = "Yeelight Color Bulb V2",
        profile = "yeelink-light-color2",
        manufacturer = "Yeelight",
        model = "yeelink.light.color2",
        vendor_provided_label = "Yeelight Color Bulb V2",
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
