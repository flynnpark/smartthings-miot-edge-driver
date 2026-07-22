local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: zhimi.airp.sa4
-- Property mappings below come from the exact MIoT specification.

air_purifier_miot.run({
    driver_name = "miot-zhimi-air-purifier-sa4",
    profile_name = "zhimi-air-purifier-sa4",
    expected_capability = "concertmirror08464.zhimiAirSa4Mode",
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
            capability = "concertmirror08464.zhimiAirSa4Mode",
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
            kind = "number",
            siid = 15,
            piid = 1,
            capability = "concertmirror08464.zhimiAirSa4FavoriteFanLevel",
            attribute = "favoriteFanLevel",
            command = "setFavoriteFanLevel",
            argument = "favoriteFanLevel",
            initial = 0
        },
        {
            kind = "enum",
            siid = 2,
            piid = 5,
            capability = "concertmirror08464.zhimiAirSa4FanLevel",
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
            siid = 6,
            piid = 1,
            capability = "concertmirror08464.zhimiAirSa4Buzzer",
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
            capability = "concertmirror08464.zhimiAirSa4ChildLock",
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
            capability = "concertmirror08464.zhimiAirSa4DisplayLevel",
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
