local log = require "log"

local discovery = {}

-- 장치 생성
function discovery.create_device(driver)
    local success, err = pcall(function()
        driver:try_create_device({
            type = "LAN",
            device_network_id = "zhimi-airpurifier-v5-" .. os.time(),
            label = "Zhimi Air Purifier V5",
            profile = "zhimi-v5",
            manufacturer = "Zhimi",
            model = "zhimi.airpurifier.v5",
            vendor_provided_label = "Zhimi Air Purifier V5",
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



