# Zhimi Fan SA1

SmartThings Edge LAN driver for the Xiaomi/miIO fan model `zhimi.fan.sa1`.

## Protocol Decision

- Protocol: miIO
- Model: `zhimi.fan.sa1`
- Basis: python-miio lists exact model `zhimi.fan.sa1` in the classic Zhimi Fan miIO integration with `get_prop` and `set_*` commands; Home Assistant Xiaomi Miio also lists this model under the classic Standing Fan platform.

## Exposed Capabilities

- `switch`
- `fanSpeedPercent`
- `fanOscillationMode`
- `concertmirror08464.zhimiFanSa1Controls`
- `refresh`

## miIO Mapping

| Feature | Access | miIO Key | SmartThings |
|---|---:|---|---|
| Power | RW | `power`, `set_power` with `on` / `off` | `switch` |
| Fan speed percent | RW | `speed_level`, `set_speed_level`, `1..100` | `fanSpeedPercent` in normal mode |
| Natural speed percent | RW | `natural_level`, `set_natural_level`, `1..100`; `0` disables natural mode | `fanSpeedPercent` in nature mode and `zhimiFanSa1Controls.fanMode` |
| Horizontal oscillation | RW | `angle_enable`, `set_angle_enable` with `on` / `off` | `fanOscillationMode` |
| LED brightness | RW | `led_b`, `set_led_b`; `0=bright`, `1=dim`, `2=off` | `zhimiFanSa1Controls.ledBrightness` |
| Buzzer | RW | `buzzer`, `set_buzzer`; `2=on`, `0=off` | `zhimiFanSa1Controls.buzzer` |
| Child lock | RW | `child_lock`, `set_child_lock` with `on` / `off` | `zhimiFanSa1Controls.childLock` |

Angle control: `zhimiFanSa1Controls.horizontalAngle` maps miIO `angle` / `set_angle`, `0..120`.

Not exposed:, rotate-left/right, AC power, use time, countdown, and raw RPM because they are auxiliary controls or diagnostic values rather than core SmartThings controls for this port.
