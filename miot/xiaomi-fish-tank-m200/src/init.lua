-- Xiaomi Smart Fishbowl M200 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miot = require "miot"

local controlsWaterPump = capabilities["concertmirror08464.xiaomiTankM200WaterPump"]
local controlsFeedProtectStatus = capabilities["concertmirror08464.xiaomiTankM200FeedProtection"]
local controlsChildLock = capabilities["concertmirror08464.xiaomiTankM200ChildLock"]
local controlsNoDisturb = capabilities["concertmirror08464.xiaomiTankM200NoDisturb"]
local controlsAlarm = capabilities["concertmirror08464.xiaomiTankM200Alarm"]
local controlsIndicatorLight = capabilities["concertmirror08464.xiaomiTankM200IndicatorLight"]
local controlsPumpFlux = capabilities["concertmirror08464.xiaomiTankM200PumpFlux"]
local controlsFeederStatus = capabilities["concertmirror08464.xiaomiTankM200FeederStatus"]
local controlsFeedProtect = capabilities["concertmirror08464.xiaomiTankM200FeedProtect"]
local controlsPumpStatus = capabilities["concertmirror08464.xiaomiTankM200PumpStatus"]
local controlsFeedNow = capabilities["concertmirror08464.xiaomiTankM200FeedNow"]
local lightLightMode = capabilities["concertmirror08464.xiaomiTankM200LightMode"]
local lightFlowSpeed = capabilities["concertmirror08464.xiaomiTankM200FlowSpeed"]
local lightLightBrightness = capabilities["concertmirror08464.xiaomiTankM200LightLevel"]
local lightLightSwitch = capabilities["concertmirror08464.xiaomiTankM200LightSwitch"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local MAX_GET_PROPERTIES = 8

-- MIoT model: xiaomi.fishbowl.m200
-- specModel: xiaomi-m200
-- URN: urn:miot-spec-v2:device:fish-tank:0000A0A2:xiaomi-m200:2
--
-- Fish Tank service (siid=2)
--   piid=1 power, bool, RW
--   piid=2 water-pump, bool, RW
--   piid=3 pump-flux, uint8, RW: 0=level1, 1=level2
--   piid=4 water-pump-status, uint8, R: 0=notConnected, 1=off, 2=on, 3=lowWater, 4=blocked, 5=fault
--   piid=5 feeding-measure, uint8, action input, 1..3
--   piid=6 temperature, uint8, R, 0..99 C
--   aiid=1 pet-food-out, action, in=[piid=5]
-- Light service (siid=3)
--   piid=1 light on, bool, RW
--   piid=2 mode, uint8, RW: 0=day, 1=flow, 3=white, 4..6=color2..4, 7=nightLight, 8=color5, 9=color6
--   piid=3 brightness, uint8, RW, 1..100 %
--   piid=4 flow-speed-level, uint8, RW: 0=low, 1=medium, 2=high
-- Private light-custom service (siid=4)
--   piid=4 light-edit-color, uint32, RW, 1..16777215, exposed as colorControl
-- Private feeder service (siid=5)
--   piid=1 feeder-status, uint8, R: 0=idle, 1=busy
--   piid=8 feed-protect-switch, bool, RW
--   piid=9 feed-protect-status, uint8, R: 0=idle, 1=busy
-- Filter service (siid=6)
--   piid=1 filter-life-level, uint8, R, 0..100 %
--   piid=2 filter-left-time, uint16, R, not exposed separately
--   aiid=1 reset-filter-life, action
-- Alarm service (siid=7)
--   piid=1 alarm/buzzer, bool, RW
-- Indicator light service (siid=8)
--   piid=1 on, bool, RW
-- Physical controls locked service (siid=9)
--   piid=1 child lock, bool, RW
-- No disturb service (siid=10)
--   piid=1 no-disturb, bool, RW

local FISH_TANK_SIID = 2
local POWER_PIID = 1
local WATER_PUMP_PIID = 2
local PUMP_FLUX_PIID = 3
local WATER_PUMP_STATUS_PIID = 4
local FEEDING_MEASURE_PIID = 5
local TEMPERATURE_PIID = 6
local PET_FOOD_OUT_AIID = 1

local LIGHT_SIID = 3
local LIGHT_SWITCH_PIID = 1
local LIGHT_MODE_PIID = 2
local LIGHT_BRIGHTNESS_PIID = 3
local FLOW_SPEED_PIID = 4

local LIGHT_CUSTOM_SIID = 4
local LIGHT_EDIT_COLOR_PIID = 4

local FEEDER_CUSTOM_SIID = 5
local FEEDER_STATUS_PIID = 1
local FEED_PROTECT_PIID = 8
local FEED_PROTECT_STATUS_PIID = 9

local FILTER_SIID = 6
local FILTER_LIFE_LEVEL_PIID = 1
local RESET_FILTER_LIFE_AIID = 1

local ALARM_SIID = 7
local ALARM_PIID = 1

local INDICATOR_LIGHT_SIID = 8
local INDICATOR_LIGHT_PIID = 1

local CHILD_LOCK_SIID = 9
local CHILD_LOCK_PIID = 1

local NO_DISTURB_SIID = 10
local NO_DISTURB_PIID = 1

local PUMP_FLUX_TO_ST = {
    [0] = "level1",
    [1] = "level2"
}

local ST_TO_PUMP_FLUX = {
    level1 = 0,
    level2 = 1
}

local PUMP_STATUS_TO_ST = {
    [0] = "notConnected",
    [1] = "off",
    [2] = "on",
    [3] = "lowWater",
    [4] = "blocked",
    [5] = "fault"
}

local FEEDER_STATUS_TO_ST = {
    [0] = "idle",
    [1] = "busy"
}

local LIGHT_MODE_TO_ST = {
    [0] = "day",
    [1] = "flow",
    [3] = "white",
    [4] = "color2",
    [5] = "color3",
    [6] = "color4",
    [7] = "nightLight",
    [8] = "color5",
    [9] = "color6"
}

local ST_TO_LIGHT_MODE = {
    day = 0,
    flow = 1,
    white = 3,
    color2 = 4,
    color3 = 5,
    color4 = 6,
    nightLight = 7,
    color5 = 8,
    color6 = 9
}

local FLOW_SPEED_TO_ST = {
    [0] = "low",
    [1] = "medium",
    [2] = "high"
}

local ST_TO_FLOW_SPEED = {
    low = 0,
    medium = 1,
    high = 2
}

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function emit_on_off(device, capability_attr, value)
    device:emit_event(capability_attr({value = value and "on" or "off"}))
end

local function get_property_results(device, ip, token, properties)
    local results = {}

    for i = 1, #properties, MAX_GET_PROPERTIES do
        local chunk = {}
        for j = i, math.min(i + MAX_GET_PROPERTIES - 1, #properties) do
            table.insert(chunk, properties[j])
        end

        local ok, response = pcall(miot.gets, device, ip, token, chunk)
        if not ok or not response or not response.result then
            return nil
        end

        for _, result in ipairs(response.result) do
            table.insert(results, result)
        end
    end

    return results
end

local function rgb_to_hs(rgb)
    local r = math.floor(rgb / 65536) % 256
    local g = math.floor(rgb / 256) % 256
    local b = rgb % 256
    local rn = r / 255
    local gn = g / 255
    local bn = b / 255
    local maxc = math.max(rn, gn, bn)
    local minc = math.min(rn, gn, bn)
    local delta = maxc - minc
    local hue = 0

    if delta ~= 0 then
        if maxc == rn then
            hue = ((gn - bn) / delta) % 6
        elseif maxc == gn then
            hue = ((bn - rn) / delta) + 2
        else
            hue = ((rn - gn) / delta) + 4
        end
        hue = hue * 60
    end

    local saturation = 0
    if maxc ~= 0 then
        saturation = delta / maxc
    end

    return clamp(hue / 3.6, 0, 100), clamp(saturation * 100, 0, 100)
end

local function hs_to_rgb(hue, saturation)
    local h = (clamp(hue, 0, 100) * 3.6) % 360
    local s = clamp(saturation, 0, 100) / 100
    local v = 1
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0

    if h < 60 then
        r, g, b = c, x, 0
    elseif h < 120 then
        r, g, b = x, c, 0
    elseif h < 180 then
        r, g, b = 0, c, x
    elseif h < 240 then
        r, g, b = 0, x, c
    elseif h < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end

    local ri = math.floor((r + m) * 255 + 0.5)
    local gi = math.floor((g + m) * 255 + 0.5)
    local bi = math.floor((b + m) * 255 + 0.5)
    return math.max(1, ri * 65536 + gi * 256 + bi)
end

local function emit_color(device, rgb)
    local hue, saturation = rgb_to_hs(rgb)
    device:emit_event(capabilities.colorControl.hue(hue))
    device:emit_event(capabilities.colorControl.saturation(saturation))
    device:emit_event(capabilities.colorControl.color({hue = hue, saturation = saturation}))
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    local properties = {
        {siid = FISH_TANK_SIID, piid = POWER_PIID},
        {siid = FISH_TANK_SIID, piid = WATER_PUMP_PIID},
        {siid = FISH_TANK_SIID, piid = PUMP_FLUX_PIID},
        {siid = FISH_TANK_SIID, piid = TEMPERATURE_PIID},
        {siid = FISH_TANK_SIID, piid = WATER_PUMP_STATUS_PIID},
        {siid = FILTER_SIID, piid = FILTER_LIFE_LEVEL_PIID},
        {siid = ALARM_SIID, piid = ALARM_PIID},
        {siid = INDICATOR_LIGHT_SIID, piid = INDICATOR_LIGHT_PIID},
        {siid = LIGHT_SIID, piid = LIGHT_SWITCH_PIID},
        {siid = LIGHT_SIID, piid = LIGHT_MODE_PIID},
        {siid = LIGHT_SIID, piid = LIGHT_BRIGHTNESS_PIID},
        {siid = LIGHT_SIID, piid = FLOW_SPEED_PIID},
        {siid = CHILD_LOCK_SIID, piid = CHILD_LOCK_PIID},
        {siid = NO_DISTURB_SIID, piid = NO_DISTURB_PIID},
        {siid = LIGHT_CUSTOM_SIID, piid = LIGHT_EDIT_COLOR_PIID},
        {siid = FEEDER_CUSTOM_SIID, piid = FEEDER_STATUS_PIID},
        {siid = FEEDER_CUSTOM_SIID, piid = FEED_PROTECT_PIID},
        {siid = FEEDER_CUSTOM_SIID, piid = FEED_PROTECT_STATUS_PIID}
    }

    local results = get_property_results(device, ip, token, properties)
    if not results then
        return
    end

    for _, result in ipairs(results) do
        if result.code == 0 then
            local siid = result.siid
            local piid = result.piid
            local value = result.value

            if siid == FISH_TANK_SIID then
                if piid == POWER_PIID then
                    device:emit_event(capabilities.switch.switch(value and "on" or "off"))
                elseif piid == WATER_PUMP_PIID then
                    emit_on_off(device, controlsWaterPump.waterPump, value)
                elseif piid == PUMP_FLUX_PIID then
                    local flux = PUMP_FLUX_TO_ST[value]
                    if flux then
                        device:emit_event(controlsPumpFlux.pumpFlux({value = flux}))
                    end
                elseif piid == TEMPERATURE_PIID then
                    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C"}))
                elseif piid == WATER_PUMP_STATUS_PIID then
                    local status = PUMP_STATUS_TO_ST[value]
                    if status then
                        device:emit_event(controlsPumpStatus.pumpStatus({value = status}))
                    end
                end
            elseif siid == FILTER_SIID and piid == FILTER_LIFE_LEVEL_PIID then
                device:emit_event(capabilities.filterState.filterLifeRemaining({value = value, unit = "%"}))
            elseif siid == ALARM_SIID and piid == ALARM_PIID then
                emit_on_off(device, controlsAlarm.alarm, value)
            elseif siid == INDICATOR_LIGHT_SIID then
                if piid == INDICATOR_LIGHT_PIID then
                    emit_on_off(device, controlsIndicatorLight.indicatorLight, value)
                end
            elseif siid == LIGHT_SIID then
                if piid == LIGHT_SWITCH_PIID then
                    emit_on_off(device, lightLightSwitch.lightSwitch, value)
                elseif piid == LIGHT_MODE_PIID then
                    local mode = LIGHT_MODE_TO_ST[value]
                    if mode then
                        device:emit_event(lightLightMode.lightMode({value = mode}))
                    end
                elseif piid == LIGHT_BRIGHTNESS_PIID then
                    device:emit_event(lightLightBrightness.lightBrightness({value = value, unit = "%"}))
                elseif piid == FLOW_SPEED_PIID then
                    local speed = FLOW_SPEED_TO_ST[value]
                    if speed then
                        device:emit_event(lightFlowSpeed.flowSpeed({value = speed}))
                    end
                end
            elseif siid == CHILD_LOCK_SIID and piid == CHILD_LOCK_PIID then
                emit_on_off(device, controlsChildLock.childLock, value)
            elseif siid == NO_DISTURB_SIID and piid == NO_DISTURB_PIID then
                emit_on_off(device, controlsNoDisturb.noDisturb, value)
            elseif siid == LIGHT_CUSTOM_SIID and piid == LIGHT_EDIT_COLOR_PIID and type(value) == "number" then
                emit_color(device, value)
            elseif siid == FEEDER_CUSTOM_SIID then
                if piid == FEEDER_STATUS_PIID then
                    local status = FEEDER_STATUS_TO_ST[value]
                    if status then
                        device:emit_event(controlsFeederStatus.feederStatus({value = status}))
                    end
                elseif piid == FEED_PROTECT_PIID then
                    emit_on_off(device, controlsFeedProtect.feedProtect, value)
                elseif piid == FEED_PROTECT_STATUS_PIID then
                    local status = FEEDER_STATUS_TO_ST[value]
                    if status then
                        device:emit_event(controlsFeedProtectStatus.feedProtectStatus({value = status}))
                    end
                end
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

    local ok = pcall(miot.set, device, ip, token, FISH_TANK_SIID, POWER_PIID, true)
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

    local ok = pcall(miot.set, device, ip, token, FISH_TANK_SIID, POWER_PIID, false)
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_water_pump_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local water_pump = command.args.waterPump
    local ok = pcall(miot.set, device, ip, token, FISH_TANK_SIID, WATER_PUMP_PIID, water_pump == "on")
    if ok then
        device:emit_event(controlsWaterPump.waterPump({value = water_pump}))
    end
end

local function set_pump_flux_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local flux = command.args.pumpFlux
    local value = ST_TO_PUMP_FLUX[flux]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, FISH_TANK_SIID, PUMP_FLUX_PIID, value)
    if ok then
        device:emit_event(controlsPumpFlux.pumpFlux({value = flux}))
    end
end

local function feed_now_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local measure = clamp(command.args.measure, 1, 3)
    local ok = pcall(miot.action, device, ip, token, FISH_TANK_SIID, PET_FOOD_OUT_AIID, {
        {piid = FEEDING_MEASURE_PIID, value = measure}
    })
    if ok then
        device:emit_event(controlsFeederStatus.feederStatus({value = "busy"}))
        device.thread:call_with_delay(2, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_alarm_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local alarm = command.args.alarm
    local ok = pcall(miot.set, device, ip, token, ALARM_SIID, ALARM_PIID, alarm == "on")
    if ok then
        device:emit_event(controlsAlarm.alarm({value = alarm}))
    end
end

local function set_indicator_light_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local indicator = command.args.indicatorLight
    local ok = pcall(miot.set, device, ip, token, INDICATOR_LIGHT_SIID, INDICATOR_LIGHT_PIID, indicator == "on")
    if ok then
        device:emit_event(controlsIndicatorLight.indicatorLight({value = indicator}))
    end
end

local function set_feed_protect_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local feed_protect = command.args.feedProtect
    local ok = pcall(miot.set, device, ip, token, FEEDER_CUSTOM_SIID, FEED_PROTECT_PIID, feed_protect == "on")
    if ok then
        device:emit_event(controlsFeedProtect.feedProtect({value = feed_protect}))
    end
end

local function set_child_lock_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local child_lock = command.args.childLock
    local ok = pcall(miot.set, device, ip, token, CHILD_LOCK_SIID, CHILD_LOCK_PIID, child_lock == "on")
    if ok then
        device:emit_event(controlsChildLock.childLock({value = child_lock}))
    end
end

local function set_no_disturb_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local no_disturb = command.args.noDisturb
    local ok = pcall(miot.set, device, ip, token, NO_DISTURB_SIID, NO_DISTURB_PIID, no_disturb == "on")
    if ok then
        device:emit_event(controlsNoDisturb.noDisturb({value = no_disturb}))
    end
end

local function set_light_switch_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local light_switch = command.args.lightSwitch
    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_SWITCH_PIID, light_switch == "on")
    if ok then
        device:emit_event(lightLightSwitch.lightSwitch({value = light_switch}))
    end
end

local function set_light_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.lightMode
    local value = ST_TO_LIGHT_MODE[mode]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_MODE_PIID, value)
    if ok then
        device:emit_event(lightLightMode.lightMode({value = mode}))
    end
end

local function set_light_brightness_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local brightness = clamp(command.args.brightness, 1, 100)
    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_BRIGHTNESS_PIID, brightness)
    if ok then
        device:emit_event(lightLightBrightness.lightBrightness({value = brightness, unit = "%"}))
    end
end

local function set_flow_speed_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local speed = command.args.flowSpeed
    local value = ST_TO_FLOW_SPEED[speed]
    if value == nil then return end

    local ok = pcall(miot.set, device, ip, token, LIGHT_SIID, FLOW_SPEED_PIID, value)
    if ok then
        device:emit_event(lightFlowSpeed.flowSpeed({value = speed}))
    end
end

local function set_color_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local color = command.args.color
    local hue = color.hue or 0
    local saturation = color.saturation or 0
    local rgb = hs_to_rgb(hue, saturation)

    pcall(miot.set, device, ip, token, LIGHT_SIID, LIGHT_SWITCH_PIID, true)
    local ok = pcall(miot.set, device, ip, token, LIGHT_CUSTOM_SIID, LIGHT_EDIT_COLOR_PIID, rgb)
    if ok then
        device:emit_event(lightLightSwitch.lightSwitch({value = "on"}))
        emit_color(device, rgb)
    end
end

local function set_hue_handler(_, device, command)
    local saturation = 100
    if device.state_cache and device.state_cache.main and device.state_cache.main.colorControl and device.state_cache.main.colorControl.saturation then
        saturation = device.state_cache.main.colorControl.saturation.value or saturation
    end
    set_color_handler(nil, device, {args = {color = {hue = command.args.hue, saturation = saturation}}})
end

local function set_saturation_handler(_, device, command)
    local hue = 0
    if device.state_cache and device.state_cache.main and device.state_cache.main.colorControl and device.state_cache.main.colorControl.hue then
        hue = device.state_cache.main.colorControl.hue.value or hue
    end
    set_color_handler(nil, device, {args = {color = {hue = hue, saturation = command.args.saturation}}})
end

local function reset_filter_handler(_, device, _)
    local ip, token = get_device_config(device)
    if not ip then return end

    local ok = pcall(miot.action, device, ip, token, FILTER_SIID, RESET_FILTER_LIFE_AIID, {})
    if ok then
        device:emit_event(capabilities.filterState.filterLifeRemaining({value = 100, unit = "%"}))
    end
end

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(controlsWaterPump.ID, "main") then
        device:try_update_metadata({profile = "xiaomi-fish-tank-m200"})
    end
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.temperatureMeasurement.temperatureRange({
        value = {minimum = 0, maximum = 99, step = 1},
        unit = "C"
    }))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.filterState.supportedFilterCommands({value = {"resetFilter"}}))
    device:emit_event(capabilities.filterState.filterLifeRemaining({value = 100, unit = "%"}))
    device:emit_event(capabilities.colorControl.hue(0))
    device:emit_event(capabilities.colorControl.saturation(100))
    device:emit_event(capabilities.colorControl.color({hue = 0, saturation = 100}))
    device:emit_event(controlsWaterPump.waterPump({value = "off"}))
    device:emit_event(controlsPumpFlux.pumpFlux({value = "level1"}))
    device:emit_event(controlsPumpStatus.pumpStatus({value = "off"}))
    device:emit_event(controlsFeederStatus.feederStatus({value = "idle"}))
    device:emit_event(controlsFeedProtect.feedProtect({value = "off"}))
    device:emit_event(controlsFeedProtectStatus.feedProtectStatus({value = "idle"}))
    device:emit_event(controlsAlarm.alarm({value = "off"}))
    device:emit_event(controlsIndicatorLight.indicatorLight({value = "on"}))
    device:emit_event(controlsChildLock.childLock({value = "off"}))
    device:emit_event(controlsNoDisturb.noDisturb({value = "off"}))
    device:emit_event(lightLightSwitch.lightSwitch({value = "off"}))
    device:emit_event(lightLightMode.lightMode({value = "day"}))
    device:emit_event(lightLightBrightness.lightBrightness({value = 100, unit = "%"}))
    device:emit_event(lightFlowSpeed.flowSpeed({value = "medium"}))
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

local driver = Driver("miot-xiaomi-fish-tank-m200", {
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
        [controlsWaterPump.ID] = {
            [controlsWaterPump.commands.setWaterPump.NAME] = set_water_pump_handler
        },
        [controlsPumpFlux.ID] = {
            [controlsPumpFlux.commands.setPumpFlux.NAME] = set_pump_flux_handler
        },
        [controlsFeedNow.ID] = {
            [controlsFeedNow.commands.feedNow.NAME] = feed_now_handler
        },
        [controlsFeedProtect.ID] = {
            [controlsFeedProtect.commands.setFeedProtect.NAME] = set_feed_protect_handler
        },
        [controlsAlarm.ID] = {
            [controlsAlarm.commands.setAlarm.NAME] = set_alarm_handler
        },
        [controlsIndicatorLight.ID] = {
            [controlsIndicatorLight.commands.setIndicatorLight.NAME] = set_indicator_light_handler
        },
        [controlsChildLock.ID] = {
            [controlsChildLock.commands.setChildLock.NAME] = set_child_lock_handler
        },
        [controlsNoDisturb.ID] = {
            [controlsNoDisturb.commands.setNoDisturb.NAME] = set_no_disturb_handler
        },
        [lightLightSwitch.ID] = {
            [lightLightSwitch.commands.setLightSwitch.NAME] = set_light_switch_handler
        },
        [lightLightMode.ID] = {
            [lightLightMode.commands.setLightMode.NAME] = set_light_mode_handler
        },
        [lightLightBrightness.ID] = {
            [lightLightBrightness.commands.setLightBrightness.NAME] = set_light_brightness_handler
        },
        [lightFlowSpeed.ID] = {
            [lightFlowSpeed.commands.setFlowSpeed.NAME] = set_flow_speed_handler
        },
        [capabilities.colorControl.ID] = {
            [capabilities.colorControl.commands.setColor.NAME] = set_color_handler,
            [capabilities.colorControl.commands.setHue.NAME] = set_hue_handler,
            [capabilities.colorControl.commands.setSaturation.NAME] = set_saturation_handler
        },
        [capabilities.filterState.ID] = {
            [capabilities.filterState.commands.resetFilter.NAME] = reset_filter_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
