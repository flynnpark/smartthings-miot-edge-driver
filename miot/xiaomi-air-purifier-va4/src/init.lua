local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: xiaomi.airp.va4
-- Property mappings below come from the exact MIoT specification.

air_purifier_miot.run({
    driver_name = "miot-xiaomi-air-purifier-va4",
    profile_name = "xiaomi-air-purifier-va4",
    expected_capability = "concertmirror08464.xiaomiAirVa4Mode",
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
            capability = "concertmirror08464.xiaomiAirVa4Mode",
            attribute = "airPurifierMode",
            command = "setAirPurifierMode",
            argument = "airPurifierMode",
            to_st = {
                [0] = "auto",
                [3] = "sleep",
                [5] = "favorite",
                [6] = "none"
            },
            from_st = {
                ["auto"] = 0,
                ["sleep"] = 3,
                ["favorite"] = 5,
                ["none"] = 6
            },
            initial = 0
        },
        {
            kind = "number",
            siid = 9,
            piid = 1,
            capability = "concertmirror08464.xiaomiAirVa4FavoriteFanLevel",
            attribute = "favoriteFanLevel",
            command = "setFavoriteFanLevel",
            argument = "favoriteFanLevel",
            initial = 0
        },
        {
            kind = "enum",
            siid = 2,
            piid = 5,
            capability = "concertmirror08464.xiaomiAirVa4FanLevel",
            attribute = "fanLevel",
            command = "setFanLevel",
            argument = "fanLevel",
            to_st = {
                [0] = "level1",
                [1] = "level2",
                [2] = "level3"
            },
            from_st = {
                ["level1"] = 0,
                ["level2"] = 1,
                ["level3"] = 2
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
            piid = 7
        },
        {
            kind = "pm25",
            siid = 3,
            piid = 4
        },
        {
            kind = "formaldehyde",
            siid = 3,
            piid = 11
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
            capability = "concertmirror08464.xiaomiAirVa4Anion",
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
            siid = 2,
            piid = 7,
            capability = "concertmirror08464.xiaomiAirVa4Uv",
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
            capability = "concertmirror08464.xiaomiAirVa4Buzzer",
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
            capability = "concertmirror08464.xiaomiAirVa4ChildLock",
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
            siid = 7,
            piid = 2,
            capability = "concertmirror08464.xiaomiAirVa4DisplayLevel",
            attribute = "displayLevel",
            command = "setDisplayLevel",
            argument = "displayLevel",
            to_st = {
                [0] = "brightest",
                [1] = "bright",
                [2] = "off"
            },
            from_st = {
                ["brightest"] = 0,
                ["bright"] = 1,
                ["off"] = 2
            },
            initial = 0
        }
    }
})
