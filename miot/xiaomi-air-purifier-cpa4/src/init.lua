local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: xiaomi.airp.cpa4
-- Property mappings below come from the exact MIoT specification.

air_purifier_miot.run({
    driver_name = "miot-xiaomi-air-purifier-cpa4",
    profile_name = "xiaomi-air-purifier-cpa4",
    expected_capability = "concertmirror08464.xiaomiAirCpa4Mode",
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
            capability = "concertmirror08464.xiaomiAirCpa4Mode",
            attribute = "airPurifierMode",
            command = "setAirPurifierMode",
            argument = "airPurifierMode",
            to_st = {
                [0] = "auto",
                [1] = "sleep",
                [2] = "favorite"
            },
            from_st = {
                ["auto"] = 0,
                ["sleep"] = 1,
                ["favorite"] = 2
            },
            initial = 0
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
            kind = "boolean",
            siid = 6,
            piid = 1,
            capability = "concertmirror08464.xiaomiAirCpa4Buzzer",
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
            capability = "concertmirror08464.xiaomiAirCpa4ChildLock",
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
            kind = "enum",
            siid = 13,
            piid = 2,
            capability = "concertmirror08464.xiaomiAirCpa4DisplayLevel",
            attribute = "displayLevel",
            command = "setDisplayLevel",
            argument = "displayLevel",
            to_st = {
                [0] = "off",
                [1] = "bright",
                [2] = "bright2"
            },
            from_st = {
                ["off"] = 0,
                ["bright"] = 1,
                ["bright2"] = 2
            },
            initial = 0
        },
        {
            kind = "number",
            siid = 9,
            piid = 11,
            capability = "concertmirror08464.xiaomiAirCpa4FanLevel",
            attribute = "fanLevel",
            command = "setFanLevel",
            argument = "fanLevel",
            initial = 0
        }
    }
})
