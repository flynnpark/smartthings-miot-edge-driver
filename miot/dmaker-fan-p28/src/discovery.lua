local capabilities = require "st.capabilities"

local discovery = {}

function discovery.create_device(driver)
    local metadata = {
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p28-" .. os.time(),
        label = "Mijia Smart DC Inverter Circulating Fan Floor Type",
        profile = "dmaker-fan-p28",
        manufacturer = "Dmaker",
        model = "dmaker.fan.p28",
        vendor_provided_label = "Mijia Smart DC Inverter Circulating Fan Floor Type"
    }

    driver:try_create_device(metadata)
end

function discovery.handle_discovery(_, _, should_continue)
    while should_continue() do
        break
    end
end

return discovery
