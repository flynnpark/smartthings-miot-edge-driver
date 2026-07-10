# Mijia DC Inverter Standing Fan E

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `dmaker.fan.1e`.

## Protocol Decision

- Protocol: MIoT
- Model: `dmaker.fan.1e`
- specModel: `dmaker-1e`
- URN: `urn:miot-spec-v2:device:fan:0000A005:dmaker-1e:1`
- Basis: Exact MIoT spec defines fan read/write properties for power, mode, swing, angle, indicator light, buzzer, child lock, and 1..100 stepless speed for `dmaker.fan.1e`; product metadata identifies it as a 2.4G Wi-Fi Xiaomi Home fan.

## Exposed Capabilities

- `switch`
- `fanSpeedPercent`
- `fanOscillationMode`
- `concertmirror08464.dmakerFan1eFanMode`
- `concertmirror08464.dmakerFan1eIndicatorLight`
- `concertmirror08464.dmakerFan1eBuzzer`
- `concertmirror08464.dmakerFan1eChildLock`
- `concertmirror08464.dmakerFan1eHorizontalAngleV2`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Stepless speed | RW | `siid=8`, `piid=1`, `1..100` | `fanSpeedPercent` |
| Horizontal swing | RW | `siid=2`, `piid=4` | `fanOscillationMode` |
| Horizontal angle | RW | `siid=2`, `piid=5`, `30/60/90/120/140` | `dmakerFan1eHorizontalAngleV2.horizontalAngle` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=normal`, `1=nature` | `dmakerFan1eFanMode.fanMode` |
| Indicator light | RW | `siid=4`, `piid=1` | `dmakerFan1eIndicatorLight.indicatorLight` |
| Buzzer | RW | `siid=5`, `piid=1` | `dmakerFan1eBuzzer.buzzer` |
| Child lock | RW | `siid=7`, `piid=1` | `dmakerFan1eChildLock.childLock` |

Not exposed: fan level bucket because SmartThings uses the 1..100 speed control, and physical shortcut helpers are not core SmartThings fan controls.
