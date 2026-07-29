local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: bj352.airp.y106cm
-- Property mappings below come from the exact MIoT specification v1.
--
-- Air Purifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=4 mode, uint8, RW enum: 1=auto, 2=sleep, 4=manual
--   piid=5 fan-level, uint8, RW enum: 1..5
--   piid=6 anion, bool, RW
--   piid=2 fault plus piid=7..12 unnamed status/fault codes: vendor
--     diagnostics, not exposed
-- Environment service (siid=3)
--   piid=1 relative-humidity, float, R, percent
--   piid=2 air-quality-index, uint16, R
--   piid=3 air-quality, uint8, R enum
--   piid=4 pm2.5-density, uint16, R
--   piid=7 temperature, float, R, celsius
--   piid=9 tvoc-density, float, R, mg/m^3
--   piid=11 hcho-density, float, R, mg/m^3
-- Left Filter service (siid=4)
--   piid=1 filter-life-level, uint8, R, percent
-- Right Filter service (siid=11)
--   piid=1 filter-life-level, uint8, R, percent
-- Indicator Light service (siid=5)
--   piid=1 on, bool, RW
-- Physical Controls Locked service (siid=8)
--   piid=1 physical-controls-locked, bool, RW
-- Other Features service (siid=9)
--   piid=2 screen, bool, RW
--   piid=1 child-lock duplicates siid=8, and piid=3/4 carry filter serial
--     strings, so neither is exposed
-- Smart Mode service (siid=10): PM and HCHO trigger thresholds are automation
--   configuration rather than a device control, not exposed
--
-- AQI and air-quality duplicate the PM2.5 reading that dustSensor already
-- reports, so only the raw densities are exposed.

air_purifier_miot.run({
    driver_name = "miot-bj352-air-purifier-y106cm",
    profile_name = "bj352-air-purifier-y106cm",
    expected_capability = "concertmirror08464.bj352AirY106Mode",
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
            capability = "concertmirror08464.bj352AirY106Mode",
            attribute = "airPurifierMode",
            command = "setAirPurifierMode",
            argument = "airPurifierMode",
            to_st = {
                [1] = "auto",
                [2] = "sleep",
                [4] = "manual"
            },
            from_st = {
                ["auto"] = 1,
                ["sleep"] = 2,
                ["manual"] = 4
            },
            initial = 1
        },
        {
            kind = "enum",
            siid = 2,
            piid = 5,
            capability = "concertmirror08464.bj352AirY106FanLevel",
            attribute = "fanLevel",
            command = "setFanLevel",
            argument = "fanLevel",
            to_st = {
                [1] = "level1",
                [2] = "level2",
                [3] = "level3",
                [4] = "level4",
                [5] = "level5"
            },
            from_st = {
                ["level1"] = 1,
                ["level2"] = 2,
                ["level3"] = 3,
                ["level4"] = 4,
                ["level5"] = 5
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
            piid = 9,
            unit = "mg/m^3"
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
            kind = "number",
            siid = 11,
            piid = 1,
            capability = "concertmirror08464.bj352AirY106FilterRight",
            attribute = "filterLife"
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 6,
            capability = "concertmirror08464.bj352AirY106Anion",
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
            siid = 5,
            piid = 1,
            capability = "concertmirror08464.bj352AirY106Indicator",
            attribute = "indicatorLight",
            command = "setIndicatorLight",
            argument = "indicatorLight",
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
            siid = 9,
            piid = 2,
            capability = "concertmirror08464.bj352AirY106Screen",
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
            capability = "concertmirror08464.bj352AirY106ChildLock",
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
