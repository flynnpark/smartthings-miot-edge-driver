-- Mijia Air Conditioner MA4 Driver

local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local discovery = require "discovery"
local miio = require "miio"

local hSwingCap = capabilities["concertmirror08464.xiaomiAcMa4HSwing"]
local vSwingCap = capabilities["concertmirror08464.xiaomiAcMa4VSwing"]
local ecoCap = capabilities["concertmirror08464.xiaomiAcMa4Eco"]
local heaterCap = capabilities["concertmirror08464.xiaomiAcMa4Heater"]
local sleepCap = capabilities["concertmirror08464.xiaomiAcMa4Sleep"]
local dryerCap = capabilities["concertmirror08464.xiaomiAcMa4Dryer"]
local alarmCap = capabilities["concertmirror08464.xiaomiAcMa4Alarm"]
local indicatorCap = capabilities["concertmirror08464.xiaomiAcMa4Indicator"]

local POLLING_TIMER = "polling_timer"
local DEFAULT_POLLING_INTERVAL = 60
local PROFILE_NAME = "xiaomi-aircondition-ma4"

-- miIO model: xiaomi.aircondition.ma4
-- specModel: xiaomi-ma4
-- URN: urn:miot-spec-v2:device:air-conditioner:0000A004:xiaomi-ma4:2
--
-- Source: hass-xiaomi-miot MIIO_TO_MIOT_SPECS entry for the exact model, which
-- extends xiaomi.aircondition.ma1 and adds the swingh override. The helper
-- converts every MIoT property into a classic get_prop read plus a set_* write,
-- so this driver speaks classic miIO directly.
--
-- Read properties (get_prop, one per request):
--   power        RW  0/1        <- MIoT siid=2 piid=1
--   mode         RW  2..5       <- siid=2 piid=2, 2=cool 3=dry 4=fan 5=heat
--   settemp      RW  16..31     <- siid=2 piid=3, celsius, 0.5 step
--   energysave   RW  0/1        <- siid=2 piid=4 (ECO)
--   auxheat      RW  0/1        <- siid=2 piid=5 (auxiliary heater)
--   sleep        RW  0/1        <- siid=2 piid=6
--   dry          RW  0/1        <- siid=2 piid=7 (auto dry)
--   wind_level   RW  0..7       <- siid=3 piid=1, 0=auto
--   swing        RW  0/1        <- siid=3 piid=2 (vertical swing)
--   swingh       RW  0/1        <- siid=3 piid=3 (horizontal swing)
--   temperature  R   celsius    <- siid=4 piid=1
--   beep         RW  0/1        <- siid=5 piid=1
--   light        RW  0/1        <- siid=6 piid=1
--
-- Write methods: set_power, set_mode, set_temp, set_energysave, set_auxheat,
--   set_sleep, set_dry, set_wind_level, set_swing, set_swingh, set_beep,
--   set_light. Boolean writes send an integer 0 or 1.
--
-- Not exposed: the maintenance examine/error strings are vendor diagnostics and
-- the enhance timer is a schedule blob rather than a device control.

local PROPERTIES = {
    "power",
    "mode",
    "settemp",
    "energysave",
    "auxheat",
    "sleep",
    "dry",
    "wind_level",
    "swing",
    "swingh",
    "temperature",
    "beep",
    "light"
}

-- miIO -> SmartThings
local MODE_TO_ST = {
    [2] = "cool",
    [3] = "dry",
    [4] = "fanOnly",
    [5] = "heat"
}

-- SmartThings -> miIO
local ST_TO_MODE = {
    cool = 2,
    dry = 3,
    fanOnly = 4,
    heat = 5
}

local SUPPORTED_AC_MODES = {"cool", "dry", "fanOnly", "heat"}

local FAN_MODE_TO_ST = {
    [0] = "auto",
    [1] = "levelOne",
    [2] = "levelTwo",
    [3] = "levelThree",
    [4] = "levelFour",
    [5] = "levelFive",
    [6] = "levelSix",
    [7] = "levelSeven"
}

local ST_TO_FAN_MODE = {
    auto = 0,
    levelOne = 1,
    levelTwo = 2,
    levelThree = 3,
    levelFour = 4,
    levelFive = 5,
    levelSix = 6,
    levelSeven = 7
}

local SUPPORTED_FAN_MODES = {
    "auto", "levelOne", "levelTwo", "levelThree",
    "levelFour", "levelFive", "levelSix", "levelSeven"
}

local TARGET_TEMPERATURE_MIN = 16
local TARGET_TEMPERATURE_MAX = 31

local function get_device_config(device)
    local ip = device.preferences.ipAddress
    local token = device.preferences.token

    if ip and ip ~= "" and token and #token == 32 then
        return ip, token
    end
    return nil, nil
end

local function ensure_profile(device)
    if not device:supports_capability_by_id(ecoCap.ID, "main") then
        device:try_update_metadata({profile = PROFILE_NAME})
    end
end

-- The converter reads these values with a "value != 0" template, so the device
-- may answer with a number or with an on/off string.
local function is_on(value)
    return value == 1 or value == true or value == "on" or value == "ON"
end

local function bool_to_st(value)
    return is_on(value) and "on" or "off"
end

local function to_number(value)
    if type(value) == "number" then
        return value
    end
    return tonumber(value)
end

local function poll_device_status(device)
    local ip, token = get_device_config(device)
    if not ip then
        return
    end

    -- The miio2miot spec sets chunk_properties to 1 for this family, so each
    -- property is read with its own get_prop request.
    local values = {}
    for _, property in ipairs(PROPERTIES) do
        local ok, response = pcall(miio.cmd, device, ip, token, "get_prop", {property})
        if ok and response and response.result then
            values[property] = response.result[1]
        end
    end

    if values.power ~= nil then
        device:emit_event(capabilities.switch.switch(bool_to_st(values.power)))
    end

    local mode = MODE_TO_ST[to_number(values.mode)]
    if mode then
        device:emit_event(capabilities.airConditionerMode.airConditionerMode(mode))
    end

    local setpoint = to_number(values.settemp)
    if setpoint then
        device:emit_event(capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = setpoint, unit = "C"}))
    end

    local temperature = to_number(values.temperature)
    if temperature then
        device:emit_event(capabilities.temperatureMeasurement.temperature({value = temperature, unit = "C"}))
    end

    local fan_mode = FAN_MODE_TO_ST[to_number(values.wind_level)]
    if fan_mode then
        device:emit_event(capabilities.airConditionerFanMode.fanMode(fan_mode))
    end

    if values.swingh ~= nil then
        device:emit_event(hSwingCap.horizontalSwing({value = bool_to_st(values.swingh)}))
    end
    if values.swing ~= nil then
        device:emit_event(vSwingCap.verticalSwing({value = bool_to_st(values.swing)}))
    end
    if values.energysave ~= nil then
        device:emit_event(ecoCap.eco({value = bool_to_st(values.energysave)}))
    end
    if values.auxheat ~= nil then
        device:emit_event(heaterCap.auxHeater({value = bool_to_st(values.auxheat)}))
    end
    if values.sleep ~= nil then
        device:emit_event(sleepCap.sleepMode({value = bool_to_st(values.sleep)}))
    end
    if values.dry ~= nil then
        device:emit_event(dryerCap.dryer({value = bool_to_st(values.dry)}))
    end
    if values.beep ~= nil then
        device:emit_event(alarmCap.alarm({value = bool_to_st(values.beep)}))
    end
    if values.light ~= nil then
        device:emit_event(indicatorCap.indicatorLight({value = bool_to_st(values.light)}))
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

    local ok = pcall(miio.set_prop, device, ip, token, "set_power", {1})
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

    local ok = pcall(miio.set_prop, device, ip, token, "set_power", {0})
    if ok then
        device:emit_event(capabilities.switch.switch.off())
    end
end

local function set_ac_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local mode = command.args.mode
    local value = ST_TO_MODE[mode]
    if value == nil then return end

    pcall(miio.set_prop, device, ip, token, "set_power", {1})
    local ok = pcall(miio.set_prop, device, ip, token, "set_mode", {value})
    if ok then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(capabilities.airConditionerMode.airConditionerMode(mode))
        device.thread:call_with_delay(1, function()
            pcall(poll_device_status, device)
        end)
    end
end

local function set_cooling_setpoint_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local setpoint = tonumber(command.args.setpoint)
    if not setpoint then return end
    if setpoint < TARGET_TEMPERATURE_MIN or setpoint > TARGET_TEMPERATURE_MAX then return end

    -- The device accepts 0.5 degree steps, so snap the requested value.
    local value = math.floor(setpoint * 2 + 0.5) / 2
    local ok = pcall(miio.set_prop, device, ip, token, "set_temp", {value})
    if ok then
        device:emit_event(capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = value, unit = "C"}))
    end
end

local function set_fan_mode_handler(_, device, command)
    local ip, token = get_device_config(device)
    if not ip then return end

    local fan_mode = command.args.fanMode
    local value = ST_TO_FAN_MODE[fan_mode]
    if value == nil then return end

    local ok = pcall(miio.set_prop, device, ip, token, "set_wind_level", {value})
    if ok then
        device:emit_event(capabilities.airConditionerFanMode.fanMode(fan_mode))
    end
end

local function make_bool_handler(method, capability, attribute, argument)
    return function(_, device, command)
        local ip, token = get_device_config(device)
        if not ip then return end

        local requested = command.args[argument]
        local ok = pcall(miio.set_prop, device, ip, token, method, {requested == "on" and 1 or 0})
        if ok then
            device:emit_event(capability[attribute]({value = requested}))
        end
    end
end

local set_h_swing_handler = make_bool_handler("set_swingh", hSwingCap, "horizontalSwing", "horizontalSwing")
local set_v_swing_handler = make_bool_handler("set_swing", vSwingCap, "verticalSwing", "verticalSwing")
local set_eco_handler = make_bool_handler("set_energysave", ecoCap, "eco", "eco")
local set_heater_handler = make_bool_handler("set_auxheat", heaterCap, "auxHeater", "auxHeater")
local set_sleep_handler = make_bool_handler("set_sleep", sleepCap, "sleepMode", "sleepMode")
local set_dryer_handler = make_bool_handler("set_dry", dryerCap, "dryer", "dryer")
local set_alarm_handler = make_bool_handler("set_beep", alarmCap, "alarm", "alarm")
local set_indicator_handler = make_bool_handler("set_light", indicatorCap, "indicatorLight", "indicatorLight")

local function refresh_handler(_, device, _)
    pcall(poll_device_status, device)
end

local function device_added(_, device)
    ensure_profile(device)
    device:emit_event(capabilities.switch.switch.off())
    device:emit_event(capabilities.airConditionerMode.supportedAcModes(SUPPORTED_AC_MODES))
    device:emit_event(capabilities.airConditionerMode.airConditionerMode("cool"))
    device:emit_event(capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = 26, unit = "C"}))
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = 0, unit = "C"}))
    device:emit_event(capabilities.airConditionerFanMode.supportedAcFanModes(SUPPORTED_FAN_MODES))
    device:emit_event(capabilities.airConditionerFanMode.fanMode("auto"))
    device:emit_event(hSwingCap.horizontalSwing({value = "off"}))
    device:emit_event(vSwingCap.verticalSwing({value = "off"}))
    device:emit_event(ecoCap.eco({value = "off"}))
    device:emit_event(heaterCap.auxHeater({value = "off"}))
    device:emit_event(sleepCap.sleepMode({value = "off"}))
    device:emit_event(dryerCap.dryer({value = "off"}))
    device:emit_event(alarmCap.alarm({value = "off"}))
    device:emit_event(indicatorCap.indicatorLight({value = "off"}))
end

local function device_init(_, device)
    ensure_profile(device)
    device:online()

    -- Re-publish the supported lists so the app keeps the selectable options.
    device:emit_event(capabilities.airConditionerMode.supportedAcModes(SUPPORTED_AC_MODES))
    device:emit_event(capabilities.airConditionerFanMode.supportedAcFanModes(SUPPORTED_FAN_MODES))

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

local driver = Driver("miio-xiaomi-aircondition-ma4", {
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
        [capabilities.airConditionerMode.ID] = {
            [capabilities.airConditionerMode.commands.setAirConditionerMode.NAME] = set_ac_mode_handler
        },
        [capabilities.thermostatCoolingSetpoint.ID] = {
            [capabilities.thermostatCoolingSetpoint.commands.setCoolingSetpoint.NAME] = set_cooling_setpoint_handler
        },
        [capabilities.airConditionerFanMode.ID] = {
            [capabilities.airConditionerFanMode.commands.setFanMode.NAME] = set_fan_mode_handler
        },
        [hSwingCap.ID] = {
            [hSwingCap.commands.setHorizontalSwing.NAME] = set_h_swing_handler
        },
        [vSwingCap.ID] = {
            [vSwingCap.commands.setVerticalSwing.NAME] = set_v_swing_handler
        },
        [ecoCap.ID] = {
            [ecoCap.commands.setEco.NAME] = set_eco_handler
        },
        [heaterCap.ID] = {
            [heaterCap.commands.setAuxHeater.NAME] = set_heater_handler
        },
        [sleepCap.ID] = {
            [sleepCap.commands.setSleepMode.NAME] = set_sleep_handler
        },
        [dryerCap.ID] = {
            [dryerCap.commands.setDryer.NAME] = set_dryer_handler
        },
        [alarmCap.ID] = {
            [alarmCap.commands.setAlarm.NAME] = set_alarm_handler
        },
        [indicatorCap.ID] = {
            [indicatorCap.commands.setIndicatorLight.NAME] = set_indicator_handler
        },
        [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler
        }
    }
})

driver:run()
