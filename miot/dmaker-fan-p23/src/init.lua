local discovery = require "discovery"
local fan_miot = require "fan_miot"

-- Exact local MIoT model: dmaker.fan.p23
-- Property mappings below come from the exact MIoT specification v1.
--
-- This model is a fan and heater combo. The SmartThings switch controls the
-- fan service, and the heater is exposed as its own power switch plus target
-- temperature and a heating flag.
--
-- Heater service (siid=2)
--   piid=1 on, bool, RW
--   piid=2 fault, uint8, R, raw code, not exposed
--   piid=4 mode, uint8, RW, single constant-temperature value, not exposed
--   piid=5 target-temperature, uint8, RW range 18..28, celsius
--   piid=6 heating, bool, RW
-- Physical Controls Locked service (siid=3)
--   piid=1 physical-controls-locked, bool, RW
-- Environment service (siid=4)
--   piid=1 relative-humidity, float, R, percent
--   piid=7 temperature, float, R, celsius
-- Fan service (siid=5)
--   piid=1 on, bool, RW
--   piid=2 fan-level, uint8, RW range 1..10 (stage, separate from the
--     1..100 percent speed in dm-service)
--   piid=3 horizontal-swing, bool, RW
--   piid=4 mode, uint8, RW enum: 0=constant temperature, 1=straight wind,
--     2=natural wind, 3=sleep
-- Alarm service (siid=7)
--   piid=1 alarm, bool, RW
-- Indicator Light service (siid=9)
--   piid=1 on, bool, RW
-- dm-service service (siid=8)
--   piid=1 speed-level, uint8, RW range 1..100 (percent speed)
--   piid=2 symmetrical-swing, bool, RW
--   piid=3 left-angle, uint8, RW range 30..150, step 5
--   piid=4 right-angle, uint8, RW range 0..120, step 5
--   piid=5 off-delay-time, uint16, RW range 0..720 minutes
--   piid=6 swing-lr-manual is a write-only nudge command, not exposed
--
-- The left and right angles are continuous stepped ranges, so they use the
-- string textField angle capabilities and the driver snaps to the 5 degree
-- step before writing.

fan_miot.run({
    driver_name = "miot-dmaker-fan-p23",
    profile_name = "dmaker-fan-p23",
    expected_capability = "concertmirror08464.dmakerFanP23LeftAngleV2",
    discovery = discovery,
    properties = {
        {
            kind = "power",
            siid = 5,
            piid = 1,
            initial = false
        },
        {
            kind = "fan_speed",
            siid = 8,
            piid = 1,
            minimum = 1,
            maximum = 100,
            initial = 1
        },
        {
            kind = "number",
            siid = 5,
            piid = 2,
            minimum = 1,
            maximum = 10,
            capability = "concertmirror08464.dmakerFanP23FanLevel",
            attribute = "fanLevel",
            command = "setFanLevel",
            argument = "fanLevel",
            initial = 1
        },
        {
            kind = "enum",
            siid = 5,
            piid = 4,
            capability = "concertmirror08464.dmakerFanP23FanMode",
            attribute = "fanMode",
            command = "setFanMode",
            argument = "fanMode",
            to_st = {
                [0] = "constantTemp",
                [1] = "straight",
                [2] = "natural",
                [3] = "sleep"
            },
            from_st = {
                ["constantTemp"] = 0,
                ["straight"] = 1,
                ["natural"] = 2,
                ["sleep"] = 3
            },
            initial = 1
        },
        {
            kind = "oscillation",
            siid = 5,
            piid = 3,
            initial = false
        },
        {
            kind = "boolean",
            siid = 8,
            piid = 2,
            capability = "concertmirror08464.dmakerFanP23Symmetric",
            attribute = "symmetricSwing",
            command = "setSymmetricSwing",
            argument = "symmetricSwing",
            initial = false
        },
        {
            kind = "angle",
            siid = 8,
            piid = 3,
            minimum = 30,
            maximum = 150,
            step = 5,
            capability = "concertmirror08464.dmakerFanP23LeftAngleV2",
            attribute = "leftAngle",
            command = "setLeftAngle",
            argument = "leftAngle",
            initial = 60
        },
        {
            kind = "angle",
            siid = 8,
            piid = 4,
            minimum = 0,
            maximum = 120,
            step = 5,
            capability = "concertmirror08464.dmakerFanP23RightAngleV2",
            attribute = "rightAngle",
            command = "setRightAngle",
            argument = "rightAngle",
            initial = 60
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 1,
            capability = "concertmirror08464.dmakerFanP23HeaterOn",
            attribute = "heaterOn",
            command = "setHeaterOn",
            argument = "heaterOn",
            initial = false
        },
        {
            kind = "number",
            siid = 2,
            piid = 5,
            minimum = 18,
            maximum = 28,
            capability = "concertmirror08464.dmakerFanP23TargetTemp",
            attribute = "targetTemperature",
            command = "setTargetTemperature",
            argument = "targetTemperature",
            initial = 24
        },
        {
            kind = "boolean",
            siid = 2,
            piid = 6,
            capability = "concertmirror08464.dmakerFanP23Heating",
            attribute = "heating",
            command = "setHeating",
            argument = "heating",
            initial = false
        },
        {
            kind = "temperature",
            siid = 4,
            piid = 7
        },
        {
            kind = "humidity",
            siid = 4,
            piid = 1
        },
        {
            kind = "number",
            siid = 8,
            piid = 5,
            minimum = 0,
            maximum = 720,
            capability = "concertmirror08464.dmakerFanP23OffDelay",
            attribute = "offDelayTime",
            command = "setOffDelayTime",
            argument = "offDelayTime",
            initial = 0
        },
        {
            kind = "boolean",
            siid = 7,
            piid = 1,
            capability = "concertmirror08464.dmakerFanP23Buzzer",
            attribute = "buzzer",
            command = "setBuzzer",
            argument = "buzzer",
            initial = false
        },
        {
            kind = "boolean",
            siid = 3,
            piid = 1,
            capability = "concertmirror08464.dmakerFanP23ChildLock",
            attribute = "childLock",
            command = "setChildLock",
            argument = "childLock",
            initial = false
        },
        {
            kind = "boolean",
            siid = 9,
            piid = 1,
            capability = "concertmirror08464.dmakerFanP23Indicator",
            attribute = "indicatorLight",
            command = "setIndicatorLight",
            argument = "indicatorLight",
            initial = true
        }
    }
})
