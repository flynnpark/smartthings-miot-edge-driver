local discovery = {}

function discovery.create_device(driver)
    local metadata = {
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p220-" .. os.time(),
        label = "Mijia Smart DC Inverter Circulating Standing Fan",
        profile = "dmaker-fan-p220",
        manufacturer = "Dmaker",
        model = "dmaker.fan.p220",
        vendor_provided_label = "Mijia Smart DC Inverter Circulating Standing Fan"
    }

    driver:try_create_device(metadata)
end

function discovery.handle_discovery(driver, _, _)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
