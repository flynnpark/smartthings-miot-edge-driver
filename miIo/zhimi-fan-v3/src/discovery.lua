local capabilities = require "st.capabilities"

local discovery = {}

function discovery.create_device(driver)
    local metadata = {
        type = "LAN",
        device_network_id = "miio-fan-zhimi-v3-" .. os.time(),
        label = "Smartmi DC Pedestal Fan",
        profile = "zhimi-fan-v3",
        manufacturer = "Zhimi",
        model = "zhimi.fan.v3",
        vendor_provided_label = "Smartmi DC Pedestal Fan"
    }

    driver:try_create_device(metadata)
end

function discovery.handle_discovery(_, _, should_continue)
    while should_continue() do
        break
    end
end

return discovery
