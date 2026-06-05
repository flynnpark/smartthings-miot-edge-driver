# Xiaomi BPLDS10DM Smart Desktop Air Circulation Fan

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `xiaomi.fan.p70`.

## Protocol Decision

- Protocol: MIoT
- Model: `xiaomi.fan.p70`
- specModel: `xiaomi-p70`
- URN: `urn:miot-spec-v2:device:fan:0000A005:xiaomi-p70:1:0000D062`
- Basis: Exact MIoT spec defines the local fan service mapping, and the Xiaomi BPLDS10DM manual links Xiaomi Home setup with `model=xiaomi.fan.p70`.

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
| Fan speed percent | RW | `siid=2`, `piid=5`, `1..100` | `fanSpeedPercent` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=normal`, `1=nature` | `xiaomiFanControls.fanMode` |
| Horizontal swing | RW | `siid=2`, `piid=6` | `fanOscillationMode`: `horizontal` / `all` |
| Vertical swing | RW | `siid=2`, `piid=8` | `fanOscillationMode`: `vertical` / `all` |
| Indicator light | RW | `siid=5`, `piid=1` | `xiaomiFanControls.indicatorLight` |
| Buzzer | RW | `siid=7`, `piid=1` | `xiaomiFanControls.buzzer` |
| Child lock | RW | `siid=8`, `piid=1` | `xiaomiFanControls.childLock` |

Not exposed: fault, gear fan level, horizontal/vertical angle, movement actions, delay timer, and dm-service shortcut actions because they are diagnostic, auxiliary, or duplicated by the exposed core controls.
