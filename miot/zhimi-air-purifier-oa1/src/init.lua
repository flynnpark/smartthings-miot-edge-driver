local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: zhimi.airpurifier.oa1
-- Property mappings below come from the exact MIoT specification.

air_purifier_miot.run({
    driver_name = "miot-zhimi-air-purifier-oa1",
    profile_name = "zhimi-air-purifier-oa1",
    expected_capability = "concertmirror08464.zhimiAirOa1FanLevel",
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
            piid = 5,
            capability = "concertmirror08464.zhimiAirOa1FanLevel",
            attribute = "fanLevel",
            command = "setFanLevel",
            argument = "fanLevel",
            to_st = {
                [1] = "level1",
                [2] = "level2",
                [3] = "level3",
                [4] = "level4"
            },
            from_st = {
                ["level1"] = 1,
                ["level2"] = 2,
                ["level3"] = 3,
                ["level4"] = 4
            },
            initial = 1
        },
        {
            kind = "filter",
            siid = 4,
            piid = 2
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 7,
            capability = "concertmirror08464.zhimiAirOa1Buzzer",
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
            siid = 2,
            piid = 9,
            capability = "concertmirror08464.zhimiAirOa1ChildLock",
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
            siid = 2,
            piid = 6,
            capability = "concertmirror08464.zhimiAirOa1DisplayLevel",
            attribute = "displayLevel",
            command = "setDisplayLevel",
            argument = "displayLevel",
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
