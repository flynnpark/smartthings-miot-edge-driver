# Plabson Slim Fan

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `pinlo.fan.fs1`.

## Protocol Decision

- Protocol: MIoT
- Model: `pinlo.fan.fs1`
- specModel: `pinlo-fs1`
- URN: `urn:miot-spec-v2:device:fan:0000A005:pinlo-fs1:1:0000D062`
- Basis: the exact MIoT spec for `pinlo.fan.fs1` exposes local MIoT fan, screen, alarm, and child-lock services with read/write siid/piid mapping.

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
| Fan speed level | RW | `siid=2`, `piid=4`, `0..3` mapped to `25/50/75/100%` | `fanSpeedPercent` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=normal`, `1=nature` | `xiaomiFanControls.fanMode` |
| Horizontal swing | RW | `siid=2`, `piid=6` | `fanOscillationMode`: `horizontal` |
| Screen | RW | `siid=6`, `piid=1` | `xiaomiFanControls.indicatorLight` |
| Child lock | RW | `siid=8`, `piid=1` | `xiaomiFanControls.childLock` |
| Buzzer | RW | `siid=11`, `piid=1` | `xiaomiFanControls.buzzer` |

Not exposed: fault, horizontal swing angle, delay timer, and toggle action because they are diagnostic, auxiliary, or duplicated by the exposed core controls.
