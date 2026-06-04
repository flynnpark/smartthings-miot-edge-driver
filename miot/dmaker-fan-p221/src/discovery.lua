local capabilities = require "st.capabilities"

local discovery = {}

function discovery.create_device(driver)
    local metadata = {
        type = "LAN",
        device_network_id = "miot-fan-dmaker-p221-" .. os.time(),
        label = "Mijia Smart DC Circulating Standing Fan Battery Edition",
        profile = "dmaker-fan-p221",
        manufacturer = "Dmaker",
        model = "dmaker.fan.p221",
        vendor_provided_label = "Mijia Smart DC Circulating Standing Fan Battery Edition"
    }

    driver:try_create_device(metadata)
end

function discovery.handle_discovery(_, _, should_continue)
    while should_continue() do
        break
    end
end

return discovery
