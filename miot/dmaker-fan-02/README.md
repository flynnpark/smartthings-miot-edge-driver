# Dream Maker Feel Fan Plus

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `dmaker.fan.02`.

## Protocol Decision

- Protocol: MIoT
- Model: `dmaker.fan.02`
- specModel: `dmaker-02`
- URN: `urn:miot-spec-v2:device:fan:0000A005:dmaker-02:1`
- Basis: Exact MIoT spec defines the local fan service and auxiliary services for `dmaker.fan.02`; product page identifies the exact model as Dream Maker Feel Fan Plus on 2.4G Wi-Fi.

## Exposed Capabilities

- `switch`
- `fanOscillationMode`
- `temperatureMeasurement`
- `relativeHumidityMeasurement`
- `concertmirror08464.dmakerFan02FanMode`
- `concertmirror08464.dmakerFan02FanLevel`
- `concertmirror08464.dmakerFan02IndicatorLight`
- `concertmirror08464.dmakerFan02Buzzer`
- `concertmirror08464.dmakerFan02ChildLock`
- `concertmirror08464.dmakerFan02HorizontalAngleV2`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Fan level | RW | `siid=2`, `piid=2`, `1..4` | `dmakerFan02FanLevel.fanLevel` |
| Horizontal swing | RW | `siid=2`, `piid=4` | `fanOscillationMode` |
| Horizontal angle | RW | `siid=2`, `piid=5`, `30/60/90/120/140` | `dmakerFan02HorizontalAngleV2.horizontalAngle` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=normal`, `1=nature`, `2=ai` | `dmakerFan02FanMode.fanMode` |
| Indicator light | RW | `siid=4`, `piid=1` | `dmakerFan02IndicatorLight.indicatorLight` |
| Buzzer | RW | `siid=5`, `piid=1` | `dmakerFan02Buzzer.buzzer` |
| Child lock | RW | `siid=7`, `piid=1` | `dmakerFan02ChildLock.childLock` |
| Temperature | R | `siid=8`, `piid=1` | `temperatureMeasurement` |
| Relative humidity | R | `siid=8`, `piid=2` | `relativeHumidityMeasurement` |

Not exposed: read-only 1..100 speed status, motor-control action, motor fault, toggle action, and off-delay because they are auxiliary or not writable core SmartThings fan controls.
