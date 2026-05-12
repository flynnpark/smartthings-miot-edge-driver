local log = require "log"

local discovery = {}

function discovery.create_device(driver)
    local success, err = pcall(function()
        driver:try_create_device({
            type = "LAN",
            device_network_id = "miot-airpurifier-rma2-" .. os.time(),
            label = "Zhimi Air Purifier RMA2",
            profile = "zhimi-rma2",
            manufacturer = "Zhimi",
            model = "zhimi.airpurifier.rma2",
            vendor_provided_label = "Zhimi Air Purifier RMA2",
        })
    end)

    if not success then
        log.error("장치 생성 실패: " .. tostring(err))
    end

    return success
end

function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
