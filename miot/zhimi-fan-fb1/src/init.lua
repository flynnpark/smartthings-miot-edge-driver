local discovery = require "discovery"
local fan_miot = require "fan_miot"

-- Exact local MIoT model: zhimi.fan.fb1
-- Property mappings below come from the exact MIoT specification v1.
--
-- Fan service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fan-level, uint8, RW range 1..5 (numeric, not an enum)
--   piid=3 horizontal-swing, bool, RW
--   piid=4 vertical-swing, bool, RW
--   piid=5 horizontal-angle, uint16, RW range 0..120
--   piid=6 vertical-angle, uint8, RW range 0..90
--   piid=7 mode, uint8, RW enum: 0=natural wind, 1=straight wind
--   piid=8 status and piid=9 fault report idle/busy and a stuck code, so they
--     are diagnostics rather than controls and are not exposed
--   piid=10 brightness, uint8, RW range 0..1 (indicator light on/off)
--   piid=11 alarm, bool, RW
-- Physical Controls Locked service (siid=6)
--   piid=1 physical-controls-locked, bool, RW
--   piid=2 current-physical-control-lock mirrors piid=1, not exposed
-- Custom service (siid=5)
--   piid=10 stepless-fan-level, uint8, RW range 1..100
--   piid=2 timing, piid=4/5 swing-back flags, piid=6/7 step-move strings, and
--     piid=8/9 one-key macros are schedule and remote-button helpers, so they
--     are not exposed
-- Custom service (siid=7): toggle actions duplicate the switch and mode writes
--
-- The horizontal and vertical angles are continuous ranges, so they use the
-- string textField angle capabilities and the driver converts to a number.

fan_miot.run({
    driver_name = "miot-zhimi-fan-fb1",
    profile_name = "zhimi-fan-fb1",
    expected_capability = "concertmirror08464.zhimiFanFb1HorizontalAngleV2",
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
            kind = "number",
            siid = 2,
            piid = 2,
            minimum = 1,
            maximum = 5,
            capability = "concertmirror08464.zhimiFanFb1FanLevel",
            attribute = "fanLevel",
            command = "setFanLevel",
            argument = "fanLevel",
            initial = 1
        },
        {
            kind = "enum",
            siid = 2,
            piid = 7,
            capability = "concertmirror08464.zhimiFanFb1FanMode",
            attribute = "fanMode",
            command = "setFanMode",
            argument = "fanMode",
            to_st = {
                [0] = "natural",
                [1] = "straight"
            },
            from_st = {
                ["natural"] = 0,
                ["straight"] = 1
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
            piid = 5,
            minimum = 0,
            maximum = 120,
            capability = "concertmirror08464.zhimiFanFb1HorizontalAngleV2",
            attribute = "horizontalAngle",
            command = "setHorizontalAngle",
            argument = "horizontalAngle",
            initial = 60
        },
        {
            kind = "angle",
            siid = 2,
            piid = 6,
            minimum = 0,
            maximum = 90,
            capability = "concertmirror08464.zhimiFanFb1VerticalAngleV2",
            attribute = "verticalAngle",
            command = "setVerticalAngle",
            argument = "verticalAngle",
            initial = 45
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 11,
            capability = "concertmirror08464.zhimiFanFb1Buzzer",
            attribute = "buzzer",
            command = "setBuzzer",
            argument = "buzzer",
            initial = false
        },
        {
            kind = "boolean",
            siid = 6,
            piid = 1,
            capability = "concertmirror08464.zhimiFanFb1ChildLock",
            attribute = "childLock",
            command = "setChildLock",
            argument = "childLock",
            initial = false
        },
        {
            kind = "enum",
            siid = 2,
            piid = 10,
            capability = "concertmirror08464.zhimiFanFb1Indicator",
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
