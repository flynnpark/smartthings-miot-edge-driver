# Mijia Smart DC Inverter Circulating Fan Floor Type

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `dmaker.fan.p28`.

## Protocol Decision

- Protocol: MIoT
- Model: `dmaker.fan.p28`
- specModel: `dmaker-p28`
- URN: `urn:miot-spec-v2:device:fan:0000A005:dmaker-p28:1`
- Basis: Exact MIoT spec defines the local siid/piid contract, and model docs identify the exact `dmaker.fan.p28` circulating fan model.

## Exposed Capabilities

- `switch`
- `fanSpeedPercent`
- `fanOscillationMode`
- `temperatureMeasurement`
- `relativeHumidityMeasurement`
- `concertmirror08464.dmakerFanP221Controls`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=normal`, `1=nature`, `2=smart`, `3=sleep` | `dmakerFanP221Controls.fanMode` |
| Stepless speed | RW | `siid=8`, `piid=1`, `1..100` | `fanSpeedPercent` |
| Horizontal swing | RW | `siid=2`, `piid=4` | `fanOscillationMode` |
| Vertical swing | RW | `siid=2`, `piid=7` | `fanOscillationMode` |
| Indicator light | RW | `siid=4`, `piid=1` | `dmakerFanP221Controls.indicatorLight` |
| Buzzer | RW | `siid=5`, `piid=1` | `dmakerFanP221Controls.buzzer` |
| Child lock | RW | `siid=7`, `piid=1` | `dmakerFanP221Controls.childLock` |
| Temperature | R | `siid=9`, `piid=1`, C | `temperatureMeasurement` |
| Humidity | R | `siid=9`, `piid=2`, % | `relativeHumidityMeasurement` |

Not exposed: gear bucket, swing angles, countdown timer, manual movement commands, swing-all shortcut, centering helpers, and loop/toggle actions are secondary controls or automation shortcuts.
