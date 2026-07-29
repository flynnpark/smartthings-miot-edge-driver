local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: baomi.airpurifier.450a
-- Property mappings below come from the exact MIoT specification v1.
--
-- Air Purifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, single no-fault value, not exposed
--   piid=4 mode, uint8, RW enum: 0=silent, 1=strong, 2=smart, 3=none
--     The vendor "none" placeholder is not offered as a selectable mode.
--   piid=5 fan-level, uint8, RW enum: 0..4 shown as level1..level5
-- Environment service (siid=3)
--   piid=4 pm2.5-density, uint16, R
-- Filter service (siid=4)
--   piid=1 filter-life-level, uint8, R, percent
-- Screen service (siid=7)
--   piid=1 on, bool, RW
-- Physical Controls Locked service (siid=8)
--   piid=1 physical-controls-locked, bool, RW
-- Alarm service (siid=11)
--   piid=1 alarm, bool, RW
-- Custom service (siid=9)
--   piid=1 filter-type, uint8, RW enum: 0=anti-mite, 1=formaldehyde, 2=baby
--   piid=2 sleep-mode, bool, RW

air_purifier_miot.run({
    driver_name = "miot-baomi-air-purifier-450a",
    profile_name = "baomi-air-purifier-450a",
    expected_capability = "concertmirror08464.baomiAir450aMode",
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
            capability = "concertmirror08464.baomiAir450aMode",
            attribute = "airPurifierMode",
            command = "setAirPurifierMode",
            argument = "airPurifierMode",
            to_st = {
                [0] = "silent",
                [1] = "strong",
                [2] = "smart"
            },
            from_st = {
                ["silent"] = 0,
                ["strong"] = 1,
                ["smart"] = 2
            },
            initial = 2
        },
        {
            kind = "enum",
            siid = 2,
            piid = 5,
            capability = "concertmirror08464.baomiAir450aFanLevel",
            attribute = "fanLevel",
            command = "setFanLevel",
            argument = "fanLevel",
            to_st = {
                [0] = "level1",
                [1] = "level2",
                [2] = "level3",
                [3] = "level4",
                [4] = "level5"
            },
            from_st = {
                ["level1"] = 0,
                ["level2"] = 1,
                ["level3"] = 2,
                ["level4"] = 3,
                ["level5"] = 4
            },
            initial = 0
        },
        {
            kind = "pm25",
            siid = 3,
            piid = 4,
            use_dust_sensor = true
        },
        {
            kind = "filter",
            siid = 4,
            piid = 1
        },
        {
            kind = "enum",
            siid = 9,
            piid = 1,
            capability = "concertmirror08464.baomiAir450aFilterType",
            attribute = "filterType",
            command = "setFilterType",
            argument = "filterType",
            to_st = {
                [0] = "mite",
                [1] = "formaldehyde",
                [2] = "babyCare"
            },
            from_st = {
                ["mite"] = 0,
                ["formaldehyde"] = 1,
                ["babyCare"] = 2
            },
            initial = 0
        },
        {
            kind = "boolean",
            siid = 7,
            piid = 1,
            capability = "concertmirror08464.baomiAir450aScreen",
            attribute = "screen",
            command = "setScreen",
            argument = "screen",
            to_st = {
                [false] = "off",
                [true] = "on"
            },
            from_st = {
                ["off"] = false,
                ["on"] = true
            },
            initial = true
        },
        {
            kind = "boolean",
            siid = 8,
            piid = 1,
            capability = "concertmirror08464.baomiAir450aChildLock",
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
            siid = 11,
            piid = 1,
            capability = "concertmirror08464.baomiAir450aBuzzer",
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
            siid = 9,
            piid = 2,
            capability = "concertmirror08464.baomiAir450aSleep",
            attribute = "sleepMode",
            command = "setSleepMode",
            argument = "sleepMode",
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
