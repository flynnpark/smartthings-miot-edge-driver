local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: zhimi.airp.ua2
-- Property mappings below come from the exact MIoT specification.

air_purifier_miot.run({
    driver_name = "miot-zhimi-air-purifier-ua2",
    profile_name = "zhimi-air-purifier-ua2",
    expected_capability = "concertmirror08464.zhimiAirUa2Mode",
    discovery = discovery,
    properties = {
        {
            kind = "power",
            siid = 2,
            piid = 1,
            initial = false
        },
        {
            kind = "enum",
            siid = 2,
            piid = 4,
            capability = "concertmirror08464.zhimiAirUa2Mode",
            attribute = "airPurifierMode",
            command = "setAirPurifierMode",
            argument = "airPurifierMode",
            to_st = {
                [0] = "auto",
                [1] = "sleep",
                [2] = "favorite",
                [3] = "manual"
            },
            from_st = {
                ["auto"] = 0,
                ["sleep"] = 1,
                ["favorite"] = 2,
                ["manual"] = 3
            },
            initial = 0
        },
        {
            kind = "enum",
            siid = 2,
            piid = 5,
            capability = "concertmirror08464.zhimiAirUa2FanLevel",
            attribute = "fanLevel",
            command = "setFanLevel",
            argument = "fanLevel",
            to_st = {
                [1] = "level1",
                [2] = "level2",
                [3] = "level3"
            },
            from_st = {
                ["level1"] = 1,
                ["level2"] = 2,
                ["level3"] = 3
            },
            initial = 1
        },
        {
            kind = "humidity",
            siid = 3,
            piid = 1
        },
        {
            kind = "temperature",
            siid = 3,
            piid = 2
        },
        {
            kind = "pm25",
            siid = 3,
            piid = 4,
            use_dust_sensor = true
        },
        {
            kind = "pm10",
            siid = 3,
            piid = 5
        },
        {
            kind = "formaldehyde",
            siid = 3,
            piid = 6
        },
        {
            kind = "filter",
            siid = 4,
            piid = 1
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 7,
            capability = "concertmirror08464.zhimiAirUa2Uv",
            attribute = "uv",
            command = "setUv",
            argument = "uv",
            to_st = {
                [false] = "off",
                [true] = "on"
            },
            from_st = {
                ["off"] = false,
                ["on"] = true
            },
            initial = false
        },
        {
            kind = "boolean",
            siid = 6,
            piid = 1,
            capability = "concertmirror08464.zhimiAirUa2Buzzer",
            attribute = "buzzer",
            command = "setBuzzer",
            argument = "buzzer",
            to_st = {
                [false] = "off",
                [true] = "on"
            },
            from_st = {
                ["off"] = false,
                ["on"] = true
            },
            initial = false
        },
        {
            kind = "boolean",
            siid = 8,
            piid = 1,
            capability = "concertmirror08464.zhimiAirUa2ChildLock",
            attribute = "childLock",
            command = "setChildLock",
            argument = "childLock",
            to_st = {
                [false] = "off",
                [true] = "on"
            },
            from_st = {
                ["off"] = false,
                ["on"] = true
            },
            initial = false
        },
        {
            kind = "boolean",
            siid = 7,
            piid = 1,
            capability = "concertmirror08464.zhimiAirUa2Display",
            attribute = "display",
            command = "setDisplay",
            argument = "display",
            to_st = {
                [false] = "off",
                [true] = "on"
            },
            from_st = {
                ["off"] = false,
                ["on"] = true
            },
            initial = false
        }
    }
})
