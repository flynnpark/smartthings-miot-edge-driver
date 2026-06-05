# Mi Smart Standing Fan 2 Lite

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `xiaomi.fan.2lite`.

## Protocol Decision

- Protocol: MIoT
- Model: `xiaomi.fan.2lite`
- specModel: `xiaomi-2lite`
- URN: `urn:miot-spec-v2:device:fan:0000A005:xiaomi-2lite:1:0000D062`
- Basis: Exact MIoT spec defines the local fan contract and model docs identify `xiaomi.fan.2lite` as the Wi-Fi Mi Smart Standing Fan 2 Lite.

## Exposed Capabilities

- `switch`
- `fanOscillationMode`
- `concertmirror08464.xiaomiFan2LiteControls`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=straight`, `1=sleep` | `xiaomiFan2LiteControls.fanMode` |
| Fan level | RW | `siid=2`, `piid=4`, `0=level1`, `1=level2`, `2=level3` | `xiaomiFan2LiteControls.fanLevel` |
| Horizontal swing | RW | `siid=2`, `piid=6` | `fanOscillationMode` |
| Indicator light | RW | `siid=5`, `piid=1` | `xiaomiFan2LiteControls.indicatorLight` |
| Buzzer | RW | `siid=7`, `piid=1` | `xiaomiFan2LiteControls.buzzer` |
| Child lock | RW | `siid=8`, `piid=1` | `xiaomiFan2LiteControls.childLock` |

Not exposed: device fault, countdown delay, delay time, delay remaining time, and the toggle action are secondary status or shortcut values.
