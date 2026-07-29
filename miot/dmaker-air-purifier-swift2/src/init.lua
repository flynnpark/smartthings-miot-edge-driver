local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: dmaker.airp.swift2
-- Property mappings below come from the exact MIoT specification v1.
--
-- This model combines a purifier and a circulating fan, so the fan service is
-- exposed with its own on switch, 1..100 speed, swing, and swing angle.
--
-- Air Purifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, vendor code, not exposed
--   piid=4 mode, uint8, RW enum: 0=smart, 1=sleep, 2=purification, 3=fan
--   piid=7 fan-level, uint8, RW enum: 1..3 (purifier stage)
--   piid=8 anion, bool, RW
-- Environment service (siid=3)
--   piid=1 relative-humidity, uint8, R, percent
--   piid=4 pm2.5-density, float, R
--   piid=7 temperature, float, R, celsius
--   piid=8 voc-density, uint16, R, ppb
-- Filter service (siid=4)
--   piid=1 filter-life-level, uint8, R, percent
--   piid=2 filter-left-time is a countdown duplicate of the life level
-- Alarm service (siid=6)
--   piid=1 alarm, bool, RW
--   piid=2 volume, uint8, RW enum 0..3
-- Screen service (siid=7)
--   piid=2 brightness, uint8, RW enum: 0=off, 1=auto, 2=half, 3=full
-- Physical Controls Locked service (siid=8)
--   piid=1 physical-controls-locked, bool, RW
-- Fan service (siid=10)
--   piid=1 on, bool, RW
--   piid=2 fan-level, uint8, RW range 1..100
--   piid=3 horizontal-swing, bool, RW
--   piid=5 horizontal-swing-included-angle, uint8, RW 30/60/90
-- dm-sevice service (siid=9): fan-mode purify overrides, per-mode rise angles,
--   anion state machine, and the filter rate setter are vendor tuning fields,
--   not exposed

air_purifier_miot.run({
    driver_name = "miot-dmaker-air-purifier-swift2",
    profile_name = "dmaker-air-purifier-swift2",
    expected_capability = "concertmirror08464.dmakerAirSwift2Mode",
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
            capability = "concertmirror08464.dmakerAirSwift2Mode",
            attribute = "airPurifierMode",
            command = "setAirPurifierMode",
            argument = "airPurifierMode",
            to_st = {
                [0] = "smart",
                [1] = "sleep",
                [2] = "purification",
                [3] = "fan"
            },
            from_st = {
                ["smart"] = 0,
                ["sleep"] = 1,
                ["purification"] = 2,
                ["fan"] = 3
            },
            initial = 0
        },
        {
            kind = "enum",
            siid = 2,
            piid = 7,
            capability = "concertmirror08464.dmakerAirSwift2FanLevel",
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
            kind = "pm25",
            siid = 3,
            piid = 4,
            use_dust_sensor = true
        },
        {
            kind = "temperature",
            siid = 3,
            piid = 7
        },
        {
            kind = "humidity",
            siid = 3,
            piid = 1
        },
        {
            kind = "tvoc",
            siid = 3,
            piid = 8,
            unit = "ppb"
        },
        {
            kind = "filter",
            siid = 4,
            piid = 1
        },
        {
            kind = "boolean",
            siid = 10,
            piid = 1,
            capability = "concertmirror08464.dmakerAirSwift2FanOn",
            attribute = "fanOn",
            command = "setFanOn",
            argument = "fanOn",
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
            kind = "number",
            siid = 10,
            piid = 2,
            capability = "concertmirror08464.dmakerAirSwift2FanSpeed",
            attribute = "fanSpeed",
            command = "setFanSpeed",
            argument = "fanSpeed",
            initial = 1
        },
        {
            kind = "boolean",
            siid = 10,
            piid = 3,
            capability = "concertmirror08464.dmakerAirSwift2Swing",
            attribute = "horizontalSwing",
            command = "setHorizontalSwing",
            argument = "horizontalSwing",
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
            siid = 10,
            piid = 5,
            capability = "concertmirror08464.dmakerAirSwift2SwingAngle",
            attribute = "swingAngle",
            command = "setSwingAngle",
            argument = "swingAngle",
            to_st = {
                [30] = "deg30",
                [60] = "deg60",
                [90] = "deg90"
            },
            from_st = {
                ["deg30"] = 30,
                ["deg60"] = 60,
                ["deg90"] = 90
            },
            initial = 30
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 8,
            capability = "concertmirror08464.dmakerAirSwift2Anion",
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
            kind = "enum",
            siid = 7,
            piid = 2,
            capability = "concertmirror08464.dmakerAirSwift2Screen",
            attribute = "screenBrightness",
            command = "setScreenBrightness",
            argument = "screenBrightness",
            to_st = {
                [0] = "off",
                [1] = "auto",
                [2] = "half",
                [3] = "full"
            },
            from_st = {
                ["off"] = 0,
                ["auto"] = 1,
                ["half"] = 2,
                ["full"] = 3
            },
            initial = 1
        },
        {
            kind = "boolean",
            siid = 6,
            piid = 1,
            capability = "concertmirror08464.dmakerAirSwift2Buzzer",
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
            kind = "number",
            siid = 6,
            piid = 2,
            capability = "concertmirror08464.dmakerAirSwift2Volume",
            attribute = "buzzerVolume",
            command = "setBuzzerVolume",
            argument = "buzzerVolume",
            initial = 2
        },
        {
            kind = "boolean",
            siid = 8,
            piid = 1,
            capability = "concertmirror08464.dmakerAirSwift2ChildLock",
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
        }
    }
})
