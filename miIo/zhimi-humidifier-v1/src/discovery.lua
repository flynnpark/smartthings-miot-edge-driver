local log = require "log"

local discovery = {}

function discovery.create_device(driver)
    local success, err = pcall(function()
        driver:try_create_device({
            type = "LAN",
            device_network_id = "zhimi-humidifier-v1-" .. os.time(),
            label = "Zhimi Humidifier V1",
            profile = "zhimi-humidifier-v1",
            manufacturer = "Zhimi",
            model = "zhimi.humidifier.v1",
            vendor_provided_label = "Zhimi Humidifier V1",
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
