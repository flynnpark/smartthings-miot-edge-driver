# Xiaomi Smart Standing Fan 2 P30

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `dmaker.fan.p30`.

## Protocol Decision

- Protocol: MIoT
- Model: `dmaker.fan.p30`
- specModel: `dmaker-p30`
- URN: `urn:miot-spec-v2:device:fan:0000A005:dmaker-p30:1`
- Basis: Exact MIoT spec defines local fan service controls for `dmaker.fan.p30`, and model/community docs identify this exact Xiaomi fan model.

## Exposed Capabilities

- `switch`
- `fanSpeedPercent`
- `fanOscillationMode`
- `concertmirror08464.xiaomiFanControls`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Stepless speed | RW | `siid=2`, `piid=10`, `1..100` | `fanSpeedPercent` |
| Horizontal swing | RW | `siid=2`, `piid=4` | `fanOscillationMode` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=normal`, `1=nature` | `xiaomiFanControls.fanMode` |
| Indicator light | RW | `siid=2`, `piid=7` | `xiaomiFanControls.indicatorLight` |
| Buzzer | RW | `siid=2`, `piid=8` | `xiaomiFanControls.buzzer` |
| Child lock | RW | `siid=3`, `piid=1` | `xiaomiFanControls.childLock` |

Not exposed: level bucket, swing angle, power-off delay, motor movement command, and toggle/loop actions are secondary controls or physical shortcut helpers.
