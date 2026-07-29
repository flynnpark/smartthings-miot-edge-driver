local discovery = require "discovery"
local fan_miot = require "fan_miot"

-- Exact local MIoT model: zhimi.fan.fa2
-- Property mappings below come from the exact MIoT specification v1.
--
-- Fan service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fan-level, uint8, RW enum: 1..4
--   piid=3 horizontal-swing, bool, RW
--   piid=4 vertical-swing, bool, RW
--   piid=7 mode, uint8, RW enum: 0=natural wind, 1=straight wind, 2=temp wind
--   piid=10 brightness, uint8, RW range 0..1 (indicator light on/off)
--   piid=11 alarm, bool, RW
--   piid=12 horizontal-angle, uint16, RW range 0..120
--   piid=14 vertical-angle, uint8, RW range 0..100
--   piid=13 and piid=15 repeat the same angle contracts for the second stored
--     preset, so only the primary angle of each axis is exposed
-- Physical Controls Locked service (siid=6)
--   piid=1 physical-controls-locked, bool, RW
-- Custom service (siid=5)
--   piid=10 stepless-fan-level, uint8, RW range 1..100
--   piid=2 timing, piid=4/5 swing-back flags, piid=6/7 step-move strings, and
--     piid=8/9 one-key macros are schedule and remote-button helpers
-- Custom service (siid=7)
--   piid=2 fan-speed, int32, R, motor rpm
--   piid=1 temp is a raw sensor value scaled by the vendor app, not exposed
--
-- The angles are continuous ranges, so they use the string textField angle
-- capabilities and the driver converts to a number.

fan_miot.run({
    driver_name = "miot-zhimi-fan-fa2",
    profile_name = "zhimi-fan-fa2",
    expected_capability = "concertmirror08464.zhimiFanFa2HorizontalAngleV2",
    discovery = discovery,
    properties = {
        {
            kind = "power",
            siid = 2,
            piid = 1,
            initial = false
        },
        {
            kind = "fan_speed",
            siid = 5,
            piid = 10,
            minimum = 1,
            maximum = 100,
            initial = 1
        },
        {
            kind = "enum",
            siid = 2,
            piid = 2,
            capability = "concertmirror08464.zhimiFanFa2FanLevel",
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
            kind = "enum",
            siid = 2,
            piid = 7,
            capability = "concertmirror08464.zhimiFanFa2FanMode",
            attribute = "fanMode",
            command = "setFanMode",
            argument = "fanMode",
            to_st = {
                [0] = "natural",
                [1] = "straight",
                [2] = "tempWind"
            },
            from_st = {
                ["natural"] = 0,
                ["straight"] = 1,
                ["tempWind"] = 2
            },
            initial = 1
        },
        {
            kind = "oscillation",
            siid = 2,
            piid = 3,
            initial = false
        },
        {
            kind = "angle",
            siid = 2,
            piid = 12,
            minimum = 0,
            maximum = 120,
            capability = "concertmirror08464.zhimiFanFa2HorizontalAngleV2",
            attribute = "horizontalAngle",
            command = "setHorizontalAngle",
            argument = "horizontalAngle",
            initial = 60
        },
        {
            kind = "angle",
            siid = 2,
            piid = 14,
            minimum = 0,
            maximum = 100,
            capability = "concertmirror08464.zhimiFanFa2VerticalAngleV2",
            attribute = "verticalAngle",
            command = "setVerticalAngle",
            argument = "verticalAngle",
            initial = 50
        },
        {
            kind = "number",
            siid = 7,
            piid = 2,
            capability = "concertmirror08464.zhimiFanFa2MotorSpeed",
            attribute = "motorSpeed"
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 11,
            capability = "concertmirror08464.zhimiFanFa2Buzzer",
            attribute = "buzzer",
            command = "setBuzzer",
            argument = "buzzer",
            initial = false
        },
        {
            kind = "boolean",
            siid = 6,
            piid = 1,
            capability = "concertmirror08464.zhimiFanFa2ChildLock",
            attribute = "childLock",
            command = "setChildLock",
            argument = "childLock",
            initial = false
        },
        {
            kind = "enum",
            siid = 2,
            piid = 10,
            capability = "concertmirror08464.zhimiFanFa2Indicator",
            attribute = "indicatorLight",
            command = "setIndicatorLight",
            argument = "indicatorLight",
            to_st = {
                [0] = "off",
                [1] = "on"
            },
            from_st = {
                ["off"] = 0,
                ["on"] = 1
            },
            initial = 1
        }
    }
})
