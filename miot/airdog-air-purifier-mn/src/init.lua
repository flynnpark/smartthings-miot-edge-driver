local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: airdog.airpurifier.mn
-- Property mappings below come from the exact MIoT specification v1.
--
-- Air Purifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, single no-fault value, not exposed
--   piid=4 mode, uint8, RW enum: 0=auto, 1=manual, 2=sleep
--   piid=5 fan-level, uint8, RW enum: 1..4
-- Environment service (siid=3)
--   piid=4 pm2.5-density, uint16, R, 0..1000
-- Filter service (siid=4): only a reset action, not exposed
-- Lock service (siid=5)
--   piid=1 zlock, bool, RW (child lock)
--   piid=2 sleep, bool, RW
--   piid=3 lighting-smart, bool, RW

air_purifier_miot.run({
    driver_name = "miot-airdog-air-purifier-mn",
    profile_name = "airdog-air-purifier-mn",
    expected_capability = "concertmirror08464.airdogAirMnMode",
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
            capability = "concertmirror08464.airdogAirMnMode",
            attribute = "airPurifierMode",
            command = "setAirPurifierMode",
            argument = "airPurifierMode",
            to_st = {
                [0] = "auto",
                [1] = "manual",
                [2] = "sleep"
            },
            from_st = {
                ["auto"] = 0,
                ["manual"] = 1,
                ["sleep"] = 2
            },
            initial = 0
        },
        {
            kind = "enum",
            siid = 2,
            piid = 5,
            capability = "concertmirror08464.airdogAirMnFanLevel",
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
            kind = "pm25",
            siid = 3,
            piid = 4,
            use_dust_sensor = true
        },
        {
            kind = "boolean",
            siid = 5,
            piid = 1,
            capability = "concertmirror08464.airdogAirMnChildLock",
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
            siid = 5,
            piid = 2,
            capability = "concertmirror08464.airdogAirMnSleep",
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
        },
        {
            kind = "boolean",
            siid = 5,
            piid = 3,
            capability = "concertmirror08464.airdogAirMnSmartLight",
            attribute = "smartLight",
            command = "setSmartLight",
            argument = "smartLight",
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
