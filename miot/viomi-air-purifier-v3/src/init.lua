local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: viomi.airp.v3
-- Property mappings below come from the exact MIoT specification v1.
--
-- Air Purifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, raw code, not exposed
--   piid=4 mode, uint8, RW enum: 0=strong, 1=smart, 2=sleep
--   piid=7 uv, bool, RW (UV sterilization lamp)
-- Environment service (siid=3)
--   piid=1 pm2.5-density, float, R
--   piid=2 air-quality, uint8, R enum, duplicates the PM2.5 reading, so it is
--     not exposed separately
-- Filter service (siid=4): declares no properties on this model
-- Indicator Light service (siid=5)
--   piid=1 on, bool, RW
-- Alarm service (siid=6)
--   piid=1 alarm, bool, RW
-- viomi-air-purifier service (siid=7)
--   piid=1 strainer-a-life, uint8, R, percent
--   piid=2 strainer-a-time is a cumulative hour counter, not exposed

air_purifier_miot.run({
    driver_name = "miot-viomi-air-purifier-v3",
    profile_name = "viomi-air-purifier-v3",
    expected_capability = "concertmirror08464.viomiAirV3Mode",
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
            capability = "concertmirror08464.viomiAirV3Mode",
            attribute = "airPurifierMode",
            command = "setAirPurifierMode",
            argument = "airPurifierMode",
            to_st = {
                [0] = "strong",
                [1] = "smart",
                [2] = "sleep"
            },
            from_st = {
                ["strong"] = 0,
                ["smart"] = 1,
                ["sleep"] = 2
            },
            initial = 1
        },
        {
            kind = "pm25",
            siid = 3,
            piid = 1,
            use_dust_sensor = true
        },
        {
            kind = "number",
            siid = 7,
            piid = 1,
            capability = "concertmirror08464.viomiAirV3FilterLife",
            attribute = "filterLife"
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 7,
            capability = "concertmirror08464.viomiAirV3Uv",
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
            siid = 5,
            piid = 1,
            capability = "concertmirror08464.viomiAirV3Indicator",
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
            siid = 6,
            piid = 1,
            capability = "concertmirror08464.viomiAirV3Buzzer",
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
        }
    }
})
