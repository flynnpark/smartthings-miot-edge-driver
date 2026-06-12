# Mijia Smart DC Inverter Circulating Standing Fan

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `dmaker.fan.p220`.

## Protocol Decision

- Protocol: MIoT
- Model: `dmaker.fan.p220`
- specModel: `dmaker-p220`
- URN: `urn:miot-spec-v2:device:fan:0000A005:dmaker-p220:1`
- Basis: Exact MIoT spec defines the same local siid/piid contract as the p221 circulating standing fan, and model/community compatibility docs identify the exact `dmaker.fan.p220` fan model.

## Exposed Capabilities

- `switch`
- `fanSpeedPercent`
- `fanOscillationMode`
- `temperatureMeasurement`
- `relativeHumidityMeasurement`
- `concertmirror08464.dmakerFanP220Controls`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=normal`, `1=nature`, `2=smart`, `3=sleep` | `dmakerFanP220Controls.fanMode` |
| Stepless speed | RW | `siid=8`, `piid=1`, `1..100` | `fanSpeedPercent` |
| Horizontal swing | RW | `siid=2`, `piid=4` | `fanOscillationMode` |
| Vertical swing | RW | `siid=2`, `piid=7` | `fanOscillationMode` |
| Indicator light | RW | `siid=4`, `piid=1` | `dmakerFanP220Controls.indicatorLight` |
| Buzzer | RW | `siid=5`, `piid=1` | `dmakerFanP220Controls.buzzer` |
| Child lock | RW | `siid=7`, `piid=1` | `dmakerFanP220Controls.childLock` |
| Temperature | R | `siid=9`, `piid=1`, C | `temperatureMeasurement` |
| Humidity | R | `siid=9`, `piid=2`, % | `relativeHumidityMeasurement` |

Angle controls: `dmakerFanP220Controls.horizontalAngle` maps `siid=2`, `piid=5`, `30/60/90/120/140`; `verticalAngle` maps `siid=2`, `piid=8`, `35/65/95`.

Not exposed: gear bucket, countdown timer, manual movement commands, automatic on/off temperature settings, and loop/toggle actions are secondary controls or automation shortcuts.
