local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: xiaomi.airp.rmb3
-- Property mappings below come from the exact MIoT specification.

air_purifier_miot.run({
    driver_name = "miot-xiaomi-air-purifier-rmb3",
    profile_name = "xiaomi-air-purifier-rmb3",
    expected_capability = "concertmirror08464.xiaomiAirRmb3Mode",
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
            piid = 3,
            capability = "concertmirror08464.xiaomiAirRmb3Mode",
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
            kind = "enum",
            siid = 9,
            piid = 1,
            capability = "concertmirror08464.xiaomiAirRmb3FanLevel",
            attribute = "fanLevel",
            command = "setFanLevel",
            argument = "fanLevel",
            to_st = {
                [0] = "level0",
                [1] = "level1",
                [2] = "level2",
                [3] = "level3",
                [4] = "level4",
                [5] = "level5",
                [6] = "level6",
                [7] = "level7",
                [8] = "level8",
                [9] = "level9",
                [10] = "level10",
                [11] = "level11",
                [12] = "level12",
                [13] = "level13",
                [14] = "level14"
            },
            from_st = {
                ["level0"] = 0,
                ["level1"] = 1,
                ["level2"] = 2,
                ["level3"] = 3,
                ["level4"] = 4,
                ["level5"] = 5,
                ["level6"] = 6,
                ["level7"] = 7,
                ["level8"] = 8,
                ["level9"] = 9,
                ["level10"] = 10,
                ["level11"] = 11,
                ["level12"] = 12,
                ["level13"] = 13,
                ["level14"] = 14
            },
            initial = 0
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
            piid = 4
        },
        {
            kind = "filter",
            siid = 4,
            piid = 1
        },
        {
            kind = "boolean",
            siid = 7,
            piid = 1,
            capability = "concertmirror08464.xiaomiAirRmb3Buzzer",
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
            capability = "concertmirror08464.xiaomiAirRmb3ChildLock",
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
            siid = 6,
            piid = 2,
            capability = "concertmirror08464.xiaomiAirRmb3DisplayLevel",
            attribute = "displayLevel",
            command = "setDisplayLevel",
            argument = "displayLevel",
            to_st = {
                [0] = "off",
                [1] = "dim",
                [2] = "bright"
            },
            from_st = {
                ["off"] = 0,
                ["dim"] = 1,
                ["bright"] = 2
            },
            initial = 0
        }
    }
})
