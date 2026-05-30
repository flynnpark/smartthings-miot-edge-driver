# Mijia Smart Inverter Air Circulation Fan Pro

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `xiaomi.fan.p90`.

## Protocol Decision

- Protocol: MIoT
- Model: `xiaomi.fan.p90`
- specModel: `xiaomi-p90`
- URN: `urn:miot-spec-v2:device:fan:0000A005:xiaomi-p90:1:0000D062`
- Basis: the exact MIoT spec for `xiaomi.fan.p90` exposes local MIoT fan, screen, alarm, and child-lock services with read/write siid/piid mapping.

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
| Fan speed percent | RW | `siid=2`, `piid=4`, `1..100` | `fanSpeedPercent` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=normal`, `1=nature` | `xiaomiFanControls.fanMode` |
| Horizontal swing | RW | `siid=2`, `piid=6` | `fanOscillationMode`: `horizontal` / `all` |
| Vertical swing | RW | `siid=2`, `piid=8` | `fanOscillationMode`: `vertical` / `all` |
| Screen | RW | `siid=6`, `piid=1` | `xiaomiFanControls.indicatorLight` |
| Buzzer | RW | `siid=7`, `piid=1` | `xiaomiFanControls.buzzer` |
| Child lock | RW | `siid=8`, `piid=1` | `xiaomiFanControls.childLock` |

Not exposed: fault, off-to-center, delay timer, asymmetrical swing angles, and dm-service shortcut actions because they are diagnostic, auxiliary, or duplicated by the exposed core controls.
