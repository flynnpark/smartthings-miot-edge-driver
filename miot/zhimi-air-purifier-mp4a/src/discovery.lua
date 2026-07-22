local discovery = {}

function discovery.create_device(driver)
    return driver:try_create_device({
        type = "LAN",
        device_network_id = "miot-airpurifier-zhimi-mp4a-" .. os.time(),
        label = "Zhimi Air Purifier MP4A",
        profile = "zhimi-air-purifier-mp4a",
        manufacturer = "Xiaomi",
        model = "zhimi.airp.mp4a",
        vendor_provided_label = "Zhimi Air Purifier MP4A"
    })
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
