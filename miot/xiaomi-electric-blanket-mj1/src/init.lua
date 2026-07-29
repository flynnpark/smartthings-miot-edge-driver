-- Xiaomi Electric Blanket MJ1 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local heatLevelControl = capabilities["concertmirror08464.xiaomiBlanketMj1HeatLevel"]
local modeControl = capabilities["concertmirror08464.xiaomiBlanketMj1Mode"]
local childLockControl = capabilities["concertmirror08464.xiaomiBlanketMj1ChildLock"]
local screenOffControl = capabilities["concertmirror08464.xiaomiBlanketMj1ScreenOff"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local EXPECTED_PROFILE_NAME = "xiaomi-electric-blanket-mj1"

-- MIoT model: xiaomi.blanket.mj1
-- specModel: xiaomi-mj1
-- URN: urn:miot-spec-v2:device:electric-blanket:0000A069:xiaomi-mj1:1
--
-- Electric Blanket service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R: 0=noFaults, not exposed
--   piid=3 mode, uint8, RW enum: 0=common, 1=miteRemoval
--   piid=7 heat-level, uint8, RW enum: 0=off, 1..6 levels
-- Physical Control Locked service (siid=3)
--   piid=1 physical-controls-locked, bool, RW
-- Screen service (siid=8)
--   piid=4 auto-screen-off, bool, RW
-- custom service (siid=6) and sleep service (siid=7): dual-zone gear values,
--   countdown timers, and sleep schedules, not exposed

local BLANKET_SIID = 2
local POWER_PIID = 1
local MODE_PIID = 3
local HEAT_LEVEL_PIID = 7

local CHILD_LOCK_SIID = 3
local CHILD_LOCK_PIID = 1

local SCREEN_SIID = 8
local AUTO_SCREEN_OFF_PIID = 4

-- MIoT -> SmartThings
local MODE_TO_ST = {
    [0] = "common",
    [1] = "miteRemoval"
}

-- SmartThings -> MIoT
local ST_TO_MODE = {
    common = 0,
    miteRemoval = 1
}

local HEAT_LEVEL_TO_ST = {
    [0] = "off",
    [1] = "levelOne",
    [2] = "levelTwo",
    [3] = "levelThree",
    [4] = "levelFour",
    [5] = "levelFive",
    [6] = "levelSix"
}

local ST_TO_HEAT_LEVEL = {
    off = 0,
    levelOne = 1,
    levelTwo = 2,
    levelThree = 3,
    levelFour = 4,
    levelFive = 5,
    levelSix = 6
}

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function bool_to_st(value)
    return value and "on" or "off"
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = BLANKET_SIID, piid = POWER_PIID},
        {siid = BLANKET_SIID, piid = MODE_PIID},
        {siid = BLANKET_SIID, piid = HEAT_LEVEL_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = SCREEN_SIID, piid = AUTO_SCREEN_OFF_PIID}
    }

    local ok, response = pcall(miot.gets, device, ip, token, properties)
    if not ok or not response or not response.result then
        return
    end

    for _, result in ipairs(response.result) do
        if result.code == 0 then
            local siid = result.siid
            local piid = result.piid
            local value = result.value

            if siid == BLANKET_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == MODE_PIID then
                    local mode = MODE_TO_ST[value]
                    if mode then
                        device:emit_event(modeControl.mode({value = mode}))
                    end
                elseif piid == HEAT_LEVEL_PIID then
                    local level = HEAT_LEVEL_TO_ST[value]
                    if level then
                        device:emit_event(heatLevelControl.heatLevel({value = level}))
                    end
                end
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                device:emit_event(childLockControl.childLock({value = bool_to_st(value)}))
            elseif siid == SCREEN_SIID and piid == AUTO_SCREEN_OFF_PIID then
                device:emit_event(screenOffControl.autoScreenOff({value = bool_to_st(value)}))
            end
        end
    end
end

local function start_polling_timer(device)
    local interval = device.preferences.pollingInterval or DEFAULT_POLLING_INTERVAL
    local timer = device.thread:call_on_schedule(interval, function()
        pcall(poll_device_status, device)
    end, "Polling")
    device:set_field(POLLING_TIMER, timer)
end

local function stop_polling_timer(device)
    local timer = device:get_field(POLLING_TIMER)
    if timer then
        device.thread:cancel_timer(timer)
        device:set_field(POLLING_TIMER, nil)
    end
end

local function switch_on_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.set, device, ip, token, BLANKET_SIID, POWER_PIID, true)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function switch_off_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.set, device, ip, token, BLANKET_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    pcall(miot.set, device, ip, token, BLANKET_SIID, POWER_PIID, true)
    local ok = pcall(miot.set, device, ip, token, BLANKET_SIID, MODE_PIID, value)
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(modeControl.mode({value = mode}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_heat_level_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local level = command.args.heatLevel
    local value = ST_TO_HEAT_LEVEL[level]
    if value == nil then return end

    -- Selecting a heat level implies the blanket should run.
    if value > 0 then
        pcall(miot.set, device, ip, token, BLANKET_SIID, POWER_PIID, true)
    end

    local ok = pcall(miot.set, device, ip, token, BLANKET_SIID, HEAT_LEVEL_PIID, value)
    if ok then
        if value > 0 then
            device:emit_event(capabilities.switch.switch.on())
        end
        device:emit_event(heatLevelControl.heatLevel({value = level}))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    local ok = pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, child_lock == "on")
    if ok then
        device:emit_event(childLockControl.childLock({value = child_lock}))
    end
end

local function set_auto_screen_off_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local screen_off = command.args.autoScreenOff
    local ok = pcall(miot.set, device, ip, token, SCREEN_SIID, AUTO_SCREEN_OFF_PIID, screen_off == "on")
    if ok then
        device:emit_event(screenOffControl.autoScreenOff({value = screen_off}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(heatLevelControl.ID, "main") then
        device:try_update_metadata({profile = EXPECTED_PROFILE_NAME})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(heatLevelControl.heatLevel({value = "off"}))
    device:emit_event(modeControl.mode({value = "common"}))
    device:emit_event(childLockControl.childLock({value = "off"}))
    device:emit_event(screenOffControl.autoScreenOff({value = "off"}))
end

local function device_init(_, device)
    ensure_profile(device)
    device:online()

    local ip = get_device_config(device)
    if ip then
        start_polling_timer(device)
        pcall(poll_device_status, device)
    end
end

local function device_removed(_, device)
    stop_polling_timer(device)
end

local function device_info_changed(driver, device, _, args)
    if not args.old_st_store or not args.old_st_store.preferences then
        return
    end

    local old = args.old_st_store.preferences
    local new = device.preferences

    if old.createDev == false and new.createDev == true then
        discovery.create_device(driver)
    end

    if old.ipAddress ~= new.ipAddress or old.token ~= new.token or old.pollingInterval ~= new.pollingInterval then
        stop_polling_timer(device)

        local ip = get_device_config(device)
        if ip then
            start_polling_timer(device)
            pcall(poll_device_status, device)
        end
    end
end

local driver = Driver("miot-xiaomi-electric-blanket-mj1", {
    discovery = discovery.handle_discovery,
    lifecycle_handlers = {
        added = device_added,
        init = device_init,
        removed = device_removed,
        infoChanged = device_info_changed
    },
    capability_handlers = {
        [capabilities.switch.ID] = {
            [capabilities.switch.commands.on.NAME] = switch_on_handler,
            [capabilities.switch.commands.off.NAME] = switch_off_handler
        },
        [heatLevelControl.ID] = {
            [heatLevelControl.commands.setHeatLevel.NAME] = set_heat_level_handler
        },
        [modeControl.ID] = {
            [modeControl.commands.setMode.NAME] = set_mode_handler
        },
        [childLockControl.ID] = {
            [childLockControl.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [screenOffControl.ID] = {
            [screenOffControl.commands.setAutoScreenOff.NAME] = set_auto_screen_off_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
