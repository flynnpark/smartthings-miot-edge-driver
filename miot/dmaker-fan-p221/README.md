# Mijia Smart DC Inverter Circulating Standing Fan Battery Edition

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `dmaker.fan.p221`.

## Protocol Decision

- Protocol: MIoT
- Model: `dmaker.fan.p221`
- specModel: `dmaker-p221`
- URN: `urn:miot-spec-v2:device:fan:0000A005:dmaker-p221:2`
- Basis: Exact MIoT spec defines the local siid/piid contract, model docs identify p221 as the p220 battery edition variant without remote control, and community SmartThings Mi-Fan compatibility lists p221.

## Exposed Capabilities

- `switch`
- `fanSpeedPercent`
- `fanOscillationMode`
- `temperatureMeasurement`
- `relativeHumidityMeasurement`
- `concertmirror08464.dmakerFanP221AngleControls`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=normal`, `1=nature`, `2=smart`, `3=sleep` | `dmakerFanP221AngleControls.fanMode` |
| Stepless speed | RW | `siid=8`, `piid=1`, `1..100` | `fanSpeedPercent` |
| Horizontal swing | RW | `siid=2`, `piid=4` | `fanOscillationMode` |
| Vertical swing | RW | `siid=2`, `piid=7` | `fanOscillationMode` |
| Indicator light | RW | `siid=4`, `piid=1` | `dmakerFanP221AngleControls.indicatorLight` |
| Buzzer | RW | `siid=5`, `piid=1` | `dmakerFanP221AngleControls.buzzer` |
| Child lock | RW | `siid=7`, `piid=1` | `dmakerFanP221AngleControls.childLock` |
| Temperature | R | `siid=9`, `piid=1`, C | `temperatureMeasurement` |
| Humidity | R | `siid=9`, `piid=2`, % | `relativeHumidityMeasurement` |

Angle controls: `dmakerFanP221AngleControls.horizontalAngle` maps `siid=2`, `piid=5`, `30/60/90/120/140`; `verticalAngle` maps `siid=2`, `piid=8`, `35/65/95`.

Not exposed: gear bucket, countdown timer, manual movement commands, automatic on/off temperature settings, and loop/toggle actions are secondary controls or automation shortcuts.
