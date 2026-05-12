local log = require "log"

local discovery = {}

function discovery.create_device(driver)
    local success, err = pcall(function()
        driver:try_create_device({
            type = "LAN",
            device_network_id = "philips-sread2-" .. os.time(),
            label = "Philips Smart Desk Lamp 2",
            profile = "philips-sread2",
            manufacturer = "Philips",
            model = "philips.light.sread2",
            vendor_provided_label = "Philips Smart Desk Lamp 2",
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
