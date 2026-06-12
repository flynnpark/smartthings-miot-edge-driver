# Smartmi Standing Fan 2S

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `zhimi.fan.za4`.

## Protocol Decision

- Protocol: MIoT
- Model: `zhimi.fan.za4`
- specModel: `zhimi-za4`
- URN: `urn:miot-spec-v2:device:fan:0000A005:zhimi-za4:3`
- Basis: `python-miio` documents exact `zhimi.fan.za4` handling and the exact MIoT spec confirms the mapped local fan properties.

## Exposed Capabilities

- `switch`
- `fanSpeedPercent`
- `fanOscillationMode`
- `concertmirror08464.zhimiFanZa4AngleControls`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Fan speed percent | RW | `siid=2`, `piid=6`, `1..100` | `fanSpeedPercent` |
| Horizontal oscillation | RW | `siid=2`, `piid=3` | `fanOscillationMode` |
| Wind mode | RW | `siid=2`, `piid=5`; `0=normal`, `1=nature` | `zhimiFanZa4AngleControls.fanMode` |
| Display brightness | RW | `siid=5`, `piid=1`; `0=normal`, `1=dim`, `2=off` | `zhimiFanZa4AngleControls.displayBrightness` |
| Buzzer | RW | `siid=4`, `piid=1` | `zhimiFanZa4AngleControls.buzzer` |
| Child lock | RW | `siid=3`, `piid=1` | `zhimiFanZa4AngleControls.childLock` |

Angle control: `zhimiFanZa4AngleControls.horizontalAngle` maps MIoT `siid=2`, `piid=4`, `0..120`.

Not exposed: fan level bucket, turn-left/right actions, and countdown because they are auxiliary controls rather than core SmartThings controls for this port.
