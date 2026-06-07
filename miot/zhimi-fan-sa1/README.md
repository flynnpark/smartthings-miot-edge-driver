# Zhimi Fan SA1

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `zhimi.fan.sa1`.

## Protocol Decision

- Protocol: MIoT
- Model: `zhimi.fan.sa1`
- specModel: `zhimi-sa1`
- URN: `urn:miot-spec-v2:device:fan:0000A005:zhimi-sa1:3`
- Basis: Exact MIoT spec v3 confirms the local MIoT fan layout with power, mode, stepless speed, horizontal swing, display brightness, buzzer, and child lock.

## Exposed Capabilities

- `switch`
- `fanSpeedPercent`
- `fanOscillationMode`
- `concertmirror08464.zhimiFanZa4Controls`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Fan speed percent | RW | `siid=2`, `piid=6`, `1..100` | `fanSpeedPercent` |
| Horizontal oscillation | RW | `siid=2`, `piid=3` | `fanOscillationMode` |
| Wind mode | RW | `siid=2`, `piid=5`; `1=nature`, `2=normal` | `zhimiFanZa4Controls.fanMode` |
| Display brightness | RW | `siid=5`, `piid=1`; `0=normal`, `1=dim`, `2=off` | `zhimiFanZa4Controls.displayBrightness` |
| Buzzer | RW | `siid=4`, `piid=1` | `zhimiFanZa4Controls.buzzer` |
| Child lock | RW | `siid=3`, `piid=1` | `zhimiFanZa4Controls.childLock` |

Not exposed: fan level bucket, horizontal angle, turn-left/right actions, and countdown because they are auxiliary controls rather than core SmartThings controls for this port.
