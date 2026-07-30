local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miio-derh-nwt-wdh318efw1-" .. os.time(),
        label = "Xiaomi Widetech Dehumidifier",
        profile = "nwt-dehumidifier-wdh318efw1",
        manufacturer = "Widetech",
        model = "nwt.derh.wdh318efw1",
        vendor_provided_label = "Xiaomi Widetech Dehumidifier"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
