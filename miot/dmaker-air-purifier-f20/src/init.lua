local discovery = require "discovery"
local air_purifier_miot = require "air_purifier_miot"

-- Exact local MIoT model: dmaker.airpurifier.f20
-- Property mappings below come from the exact MIoT specification v2.
--
-- Air Purifier service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint16, R, raw code, not exposed
--   piid=4 mode, uint8, RW enum: 0=auto, 1=sleep, 2..4=level1..3, 5=favorite
--   piid=6 door-state, bool, R (filter cover open)
--   piid=7 fan-level mirrors the same enum as piid=4, so only the mode
--     property is exposed to avoid two controls for one device setting
-- Environment service (siid=3)
--   piid=1 relative-humidity, uint8, R, percent
--   piid=4 pm2.5-density, float, R
--   piid=5 pm10-density, float, R
--   piid=7 temperature, float, R, celsius
-- Filter service (siid=4)
--   piid=1 filter-life-level, uint8, R, percent
--   piid=2..5 filter time and airflow counters: cumulative stats, not exposed
-- Alarm service (siid=6)
--   piid=1 alarm, bool, RW
--   piid=2 volume, uint8, RW range 0..100
-- Screen service (siid=7)
--   piid=1 on, bool, RW
--   piid=2 brightness, uint8, RW range 0..100
-- Physical Controls Locked service (siid=8)
--   piid=1 physical-controls-locked, bool, RW
-- dm-sevice service (siid=9): favorite motor speed, motor feedback, filter
--   events, and PM debug values are vendor tuning fields, not exposed

air_purifier_miot.run({
    driver_name = "miot-dmaker-air-purifier-f20",
    profile_name = "dmaker-air-purifier-f20",
    expected_capability = "concertmirror08464.dmakerAirF20Mode",
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
            capability = "concertmirror08464.dmakerAirF20Mode",
            attribute = "airPurifierMode",
            command = "setAirPurifierMode",
            argument = "airPurifierMode",
            to_st = {
                [0] = "auto",
                [1] = "sleep",
                [2] = "level1",
                [3] = "level2",
                [4] = "level3",
                [5] = "favorite"
            },
            from_st = {
                ["auto"] = 0,
                ["sleep"] = 1,
                ["level1"] = 2,
                ["level2"] = 3,
                ["level3"] = 4,
                ["favorite"] = 5
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
            kind = "pm10",
            siid = 3,
            piid = 5
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
            kind = "filter",
            siid = 4,
            piid = 1
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 6,
            capability = "concertmirror08464.dmakerAirF20DoorOpen",
            attribute = "doorOpen",
            to_st = {
                [false] = "closed",
                [true] = "open"
            },
            initial = false
        },
        {
            kind = "boolean",
            siid = 7,
            piid = 1,
            capability = "concertmirror08464.dmakerAirF20Screen",
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
            kind = "number",
            siid = 7,
            piid = 2,
            capability = "concertmirror08464.dmakerAirF20Brightness",
            attribute = "screenBrightness",
            command = "setScreenBrightness",
            argument = "screenBrightness",
            initial = 100
        },
        {
            kind = "boolean",
            siid = 6,
            piid = 1,
            capability = "concertmirror08464.dmakerAirF20Buzzer",
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
            capability = "concertmirror08464.dmakerAirF20Volume",
            attribute = "buzzerVolume",
            command = "setBuzzerVolume",
            argument = "buzzerVolume",
            initial = 50
        },
        {
            kind = "boolean",
            siid = 8,
            piid = 1,
            capability = "concertmirror08464.dmakerAirF20ChildLock",
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
