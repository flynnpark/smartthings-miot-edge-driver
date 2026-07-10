# Mijia Circulation Fan

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `xiaomi.fan.p51`.

## Protocol Decision

- Protocol: MIoT
- Model: `xiaomi.fan.p51`
- specModel: `xiaomi-p51`
- URN: `urn:miot-spec-v2:device:fan:0000A005:xiaomi-p51:1`
- Basis: Exact MIoT spec defines fan `siid=2` read/write properties for power, speed, mode, swing, angle, indicator light, buzzer, and child lock for `xiaomi.fan.p51`.

## Exposed Capabilities

- `switch`
- `fanSpeedPercent`
- `fanOscillationMode`
- `concertmirror08464.xiaomiFanP51FanMode`
- `concertmirror08464.xiaomiFanP51IndicatorLight`
- `concertmirror08464.xiaomiFanP51Buzzer`
- `concertmirror08464.xiaomiFanP51ChildLock`
- `concertmirror08464.xiaomiFanP51HorizontalAngleV2`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Stepless speed | RW | `siid=2`, `piid=6`, `1..100` | `fanSpeedPercent` |
| Horizontal swing | RW | `siid=2`, `piid=4` | `fanOscillationMode` |
| Horizontal angle | RW | `siid=2`, `piid=5`, `30/60/90/120` | `xiaomiFanP51HorizontalAngleV2.horizontalAngle` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=normal`, `1=nature` | `xiaomiFanP51FanMode.fanMode` |
| Indicator light | RW | `siid=5`, `piid=1` | `xiaomiFanP51IndicatorLight.indicatorLight` |
| Buzzer | RW | `siid=6`, `piid=1` | `xiaomiFanP51Buzzer.buzzer` |
| Child lock | RW | `siid=7`, `piid=1` | `xiaomiFanP51ChildLock.childLock` |

Not exposed: level bucket, toggle/turn actions, and private dm-service actions because they are auxiliary values or physical shortcut helpers rather than core SmartThings fan controls.
