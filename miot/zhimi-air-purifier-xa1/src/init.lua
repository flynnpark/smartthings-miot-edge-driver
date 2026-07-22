local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: zhimi.airpurifier.xa1
-- Property mappings below come from the exact MIoT specification.

air_purifier_miot.run({
    driver_name = "miot-zhimi-air-purifier-xa1",
    profile_name = "zhimi-air-purifier-xa1",
    expected_capability = "concertmirror08464.zhimiAirXa1Mode",
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
            capability = "concertmirror08464.zhimiAirXa1Mode",
            attribute = "airPurifierMode",
            command = "setAirPurifierMode",
            argument = "airPurifierMode",
            to_st = {
                [0] = "auto",
                [1] = "sleep",
                [2] = "favorite",
                [3] = "none"
            },
            from_st = {
                ["auto"] = 0,
                ["sleep"] = 1,
                ["favorite"] = 2,
                ["none"] = 3
            },
            initial = 0
        },
        {
            kind = "enum",
            siid = 2,
            piid = 3,
            capability = "concertmirror08464.zhimiAirXa1FanLevel",
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
            piid = 7
        },
        {
            kind = "pm25",
            siid = 3,
            piid = 4
        },
        {
            kind = "filter",
            siid = 4,
            piid = 1
        },
        {
            kind = "tvoc",
            siid = 3,
            piid = 8,
            unit = "ug/m3"
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 5,
            capability = "concertmirror08464.zhimiAirXa1Anion",
            attribute = "anion",
            command = "setAnion",
            argument = "anion",
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
            siid = 15,
            piid = 1,
            capability = "concertmirror08464.zhimiAirXa1Buzzer",
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
            siid = 14,
            piid = 1,
            capability = "concertmirror08464.zhimiAirXa1ChildLock",
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
            siid = 6,
            piid = 2,
            capability = "concertmirror08464.zhimiAirXa1Display",
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
        },
        {
            kind = "enum",
            siid = 6,
            piid = 3,
            capability = "concertmirror08464.zhimiAirXa1DisplayLevel",
            attribute = "displayLevel",
            command = "setDisplayLevel",
            argument = "displayLevel",
            to_st = {
                [0] = "off",
                [1] = "auto",
                [2] = "brightest",
                [3] = "bright"
            },
            from_st = {
                ["off"] = 0,
                ["auto"] = 1,
                ["brightest"] = 2,
                ["bright"] = 3
            },
            initial = 0
        },
        {
            kind = "enum",
            siid = 11,
            piid = 10,
            capability = "concertmirror08464.zhimiAirXa1ShutterAngle",
            attribute = "shutterAngle",
            command = "setShutterAngle",
            argument = "shutterAngle",
            to_st = {
                [0] = "thirty",
                [1] = "sixty",
                [2] = "ninety"
            },
            from_st = {
                ["thirty"] = 0,
                ["sixty"] = 1,
                ["ninety"] = 2
            },
            initial = 0
        }
    }
})
