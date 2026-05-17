local log = require "log"

local discovery = {}

function discovery.create_device(driver)
    local success, err = pcall(function()
        driver:try_create_device({
            type = "LAN",
            device_network_id = "dmaker-fan-p5-" .. os.time(),
            label = "Mi Smart Standing Fan 1X",
            profile = "dmaker-fan-p5",
            manufacturer = "Xiaomi",
            model = "dmaker.fan.p5",
            vendor_provided_label = "Mi Smart Standing Fan 1X",
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

