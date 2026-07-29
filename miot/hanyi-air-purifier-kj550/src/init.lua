local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: hanyi.airpurifier.kj550
-- Property mappings below come from the exact MIoT specification v1.
--
-- Air Purifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, single no-fault value, not exposed
--   piid=4 mode, uint8, RW enum: 0=auto, 1=sleep, 2=manual
--   piid=5 fan-level, uint8, RW range 0..100 (stepless, not an enum)
--   piid=6 anion, bool, RW
-- Environment service (siid=3)
--   piid=4 pm2.5-density, uint16, R
--   piid=5 indoor-temperature, int16, R, celsius
--   piid=6 relative-humidity, uint8, R, percent
-- Filter service (siid=4)
--   piid=2 filter-left-time, uint16, R, hours
-- Indicator Light service (siid=5)
--   piid=1 on, uint8, RW enum: 0=close, 1=bright, 2=dark
-- Custom service (siid=6)
--   piid=1 childlock, bool, RW
--   piid=2 reset, piid=3/4 timer setters, and piid=5/6 remaining countdowns
--     are maintenance and schedule fields, not exposed

air_purifier_miot.run({
    driver_name = "miot-hanyi-air-purifier-kj550",
    profile_name = "hanyi-air-purifier-kj550",
    expected_capability = "concertmirror08464.hanyiAirKj550Mode",
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
            capability = "concertmirror08464.hanyiAirKj550Mode",
            attribute = "airPurifierMode",
            command = "setAirPurifierMode",
            argument = "airPurifierMode",
            to_st = {
                [0] = "auto",
                [1] = "sleep",
                [2] = "manual"
            },
            from_st = {
                ["auto"] = 0,
                ["sleep"] = 1,
                ["manual"] = 2
            },
            initial = 0
        },
        {
            kind = "number",
            siid = 2,
            piid = 5,
            capability = "concertmirror08464.hanyiAirKj550FanSpeed",
            attribute = "fanSpeed",
            command = "setFanSpeed",
            argument = "fanSpeed",
            initial = 0
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
            piid = 5
        },
        {
            kind = "humidity",
            siid = 3,
            piid = 6
        },
        {
            kind = "number",
            siid = 4,
            piid = 2,
            capability = "concertmirror08464.hanyiAirKj550FilterTime",
            attribute = "filterLeftTime"
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 6,
            capability = "concertmirror08464.hanyiAirKj550Anion",
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
            siid = 5,
            piid = 1,
            capability = "concertmirror08464.hanyiAirKj550Indicator",
            attribute = "indicatorBrightness",
            command = "setIndicatorBrightness",
            argument = "indicatorBrightness",
            to_st = {
                [0] = "off",
                [1] = "bright",
                [2] = "dark"
            },
            from_st = {
                ["off"] = 0,
                ["bright"] = 1,
                ["dark"] = 2
            },
            initial = 1
        },
        {
            kind = "boolean",
            siid = 6,
            piid = 1,
            capability = "concertmirror08464.hanyiAirKj550ChildLock",
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
