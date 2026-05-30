# Smartmi Standing Fan 3

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `zhimi.fan.za5`.

## Protocol Decision

- Protocol: MIoT
- Model: `zhimi.fan.za5`
- specModel: `zhimi-za5`
- URN: `urn:miot-spec-v2:device:fan:0000A005:zhimi-za5:4`
- Basis: python-miio `FanZA5` maps exact model `zhimi.fan.za5` with MIoT siid/piid properties; model docs identify it as Smartmi Standing Fan 3; exact MIoT spec confirms the mapped properties below.

## Exposed Capabilities

- `switch`
- `fanSpeedPercent`
- `fanOscillationMode`
- `temperatureMeasurement`
- `relativeHumidityMeasurement`
- `concertmirror08464.zhimiFanZa5Controls`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Fan speed percent | RW | `siid=6`, `piid=8`, `1..100` | `fanSpeedPercent` |
| Horizontal oscillation | RW | `siid=2`, `piid=3` | `fanOscillationMode` |
| Wind mode | RW | `siid=2`, `piid=7`, `0=nature`, `1=normal` | `zhimiFanZa5Controls.fanMode` |
| Anion | RW | `siid=2`, `piid=11` | `zhimiFanZa5Controls.anion` |
| Display brightness | RW | `siid=4`, `piid=3`, `0..100 %` | `zhimiFanZa5Controls.displayBrightness` |
| Buzzer | RW | `siid=5`, `piid=1` | `zhimiFanZa5Controls.buzzer` |
| Child lock | RW | `siid=3`, `piid=1` | `zhimiFanZa5Controls.childLock` |
| Humidity | R | `siid=7`, `piid=1`, `%` | `relativeHumidityMeasurement` |
| Temperature | R | `siid=7`, `piid=7`, `C` | `temperatureMeasurement` |

Not exposed: fan level bucket, horizontal angle, off-delay, button record, battery/power metadata, step movement, motor RPM, motor status, country code, and private temperature-sensor setting because they are auxiliary, diagnostic, or not core SmartThings controls.
