local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: zhimi.airp.mp4a
-- Property mappings below come from the exact MIoT specification.

air_purifier_miot.run({
    driver_name = "miot-zhimi-air-purifier-mp4a",
    profile_name = "zhimi-air-purifier-mp4a",
    expected_capability = "concertmirror08464.zhimiAirMp4aMode",
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
            capability = "concertmirror08464.zhimiAirMp4aMode",
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
            capability = "concertmirror08464.zhimiAirMp4aFanLevel",
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
            kind = "boolean",
            siid = 2,
            piid = 6,
            capability = "concertmirror08464.zhimiAirMp4aAnion",
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
            siid = 6,
            piid = 1,
            capability = "concertmirror08464.zhimiAirMp4aBuzzer",
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
            capability = "concertmirror08464.zhimiAirMp4aChildLock",
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
            capability = "concertmirror08464.zhimiAirMp4aDisplayLevel",
            attribute = "displayLevel",
            command = "setDisplayLevel",
            argument = "displayLevel",
            to_st = {
                [0] = "off",
                [1] = "bright",
                [2] = "brightest"
            },
            from_st = {
                ["off"] = 0,
                ["bright"] = 1,
                ["brightest"] = 2
            },
            initial = 0
        }
    }
})
