# Smartmi DC Pedestal Fan

SmartThings Edge LAN driver for the Xiaomi/miIO fan model `zhimi.fan.v3`.

## Protocol Decision

- Protocol: miIO
- Model: `zhimi.fan.v3`
- specModel: `zhimi-v3`
- URN: `urn:miot-spec-v2:device:fan:0000A005:zhimi-v3:3`
- Basis: python-miio lists `zhimi.fan.v3` in the classic `Fan` miIO integration and defines the local `get_prop` and `set_*` methods used here.

## Exposed Capabilities

- `switch`
- `fanSpeedPercent`
- `fanOscillationMode`
- `temperatureMeasurement`
- `relativeHumidityMeasurement`
- `battery`
- `concertmirror08464.zhimiFanV3AngleControls`
- `refresh`

## miIO Mapping

| Feature | Access | miIO Key | SmartThings |
|---|---:|---|---|
| Power | RW | `power`, `set_power` with `on` / `off` | `switch` |
| Direct speed | RW | `speed_level`, `set_speed_level`, `0..100` | `fanSpeedPercent` in normal mode |
| Natural speed | RW | `natural_level`, `set_natural_level`, `0..100` | `fanSpeedPercent` in nature mode, `fanMode` |
| Oscillation | RW | `angle_enable`, `set_angle_enable` with `on` / `off` | `fanOscillationMode` |
| Temperature | R | `temp_dec`, deci-Celsius | `temperatureMeasurement` |
| Humidity | R | `humidity`, percent | `relativeHumidityMeasurement` |
| Battery | R | `battery`, percent | `battery` |
| Display brightness | RW | `led_b`, `set_led_b`, `0=bright`, `1=dim`, `2=off` | `zhimiFanV3AngleControls.ledBrightness` |
| Buzzer | RW | `buzzer`, `set_buzzer` with `on` / `off` | `zhimiFanV3AngleControls.buzzer` |
| Child lock | RW | `child_lock`, `set_child_lock` with `on` / `off` | `zhimiFanV3AngleControls.childLock` |

Angle control: `zhimiFanV3AngleControls.horizontalAngle` maps miIO `angle` / `set_angle`, `30..120`.

Not exposed: motor RPM, AC power state, button record, delay countdown, use time, battery charging state, and manual left/right movement are auxiliary metadata or secondary controls.
