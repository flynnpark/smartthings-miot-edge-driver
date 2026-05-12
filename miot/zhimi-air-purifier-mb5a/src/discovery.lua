local log = require "log"

local discovery = {}

-- 장치 생성
function discovery.create_device(driver)
    local success, err = pcall(function()
        driver:try_create_device({
            type = "LAN",
            device_network_id = "miot-airpurifier-mb5a-" .. os.time(),
            label = "Zhimi Air Purifier MB5A",
            profile = "zhimi-mb5a",
            manufacturer = "Zhimi",
            model = "zhimi.airp.mb5a",
            vendor_provided_label = "Zhimi Air Purifier MB5A",
        })
    end)
    
    if not success then
        log.error("장치 생성 실패: " .. tostring(err))
    end
    
    return success
end

-- 장치 검색 핸들러
function discovery.handle_discovery(driver, opts, cont)
    if #driver:get_devices() == 0 then
        discovery.create_device(driver)
    end
end

return discovery
