# Mijia Smart DC Inverter Circulation Fan Pro

SmartThings Edge LAN driver for the Xiaomi MIoT fan model `xiaomi.fan.p90`.

## Protocol Decision

- Protocol: native MIoT over the local miIO UDP transport
- Model: `xiaomi.fan.p90`
- specModel: `xiaomi-p90`
- URN: `urn:miot-spec-v2:device:fan:0000A005:xiaomi-p90:1:0000D062`
- Specification: [Xiaomi MIoT spec](https://home.miot-spec.com/spec/xiaomi.fan.p90)
- Basis: a real device with this exact model returned `code=0` to one authenticated LAN `get_properties` request for all mapped core and auxiliary properties.
- Evidence: confirmed. The observed LAN response was cross-checked against the exact MIoT spec. See "Evidence Grades" in the root README.md.

## Installation

1. Enroll the SmartThings location in the repository installation channel.
2. Install `Xiaomi Fan P90 Driver`.
3. Add the driver device in the SmartThings app.
4. Set `ipAddress`, `token`, and `pollingInterval` in preferences.
5. Toggle `createDev` only when another independently configured p90 device is needed.

## Exposed Capabilities

The driver uses SmartThings production capabilities for the core fan controls and
the repository's established fan custom capabilities for MIoT-specific controls:

- `switch` on `main`: fan power
- `fanSpeedPercent`: fan speed, constrained by the device to `1..100`
- `concertmirror08464.xiaomiFanP43FanMode`: Normal / Nature
- `fanOscillationMode`: `off`, `horizontal`, `vertical`, and `all`
- `concertmirror08464.xiaomiFanP43IndicatorLight`: display on/off
- `concertmirror08464.xiaomiFanP43Buzzer`: buzzer on/off
- `concertmirror08464.xiaomiFanP43ChildLock`: child lock on/off
- `refresh`

The custom capabilities are reused from the p43 driver because their semantics and
presentations match the p90 properties. Keeping them on `main` prevents the
SmartThings app from rendering separate component headers and power cards.

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `main.switch` |
| Wind mode | RW | `siid=2`, `piid=3`, `0=normal`, `1=nature` | `xiaomiFanP43FanMode.fanMode` |
| Fan speed | RW | `siid=2`, `piid=4`, `1..100` | `main.fanSpeedPercent` |
| Horizontal oscillation | RW | `siid=2`, `piid=6` | `main.fanOscillationMode`: `horizontal` / `all` |
| Vertical oscillation | RW | `siid=2`, `piid=8` | `main.fanOscillationMode`: `vertical` / `all` |
| Display | RW | `siid=6`, `piid=1` | `xiaomiFanP43IndicatorLight.indicatorLight` |
| Buzzer | RW | `siid=7`, `piid=1` | `xiaomiFanP43Buzzer.buzzer` |
| Child lock | RW | `siid=8`, `piid=1` | `xiaomiFanP43ChildLock.childLock` |

The speed and horizontal-oscillation keys deliberately differ from `xiaomi.fan.p43`: p90 uses `2/4` for speed and `2/6` for horizontal oscillation.

## Known Limitations

- The driver controls only the documented core and auxiliary properties above. Fault state, off-to-center, delay, and `dm-service` controls are intentionally not exposed.
- A LAN token, a reachable device IP address, and the same network segment as the SmartThings hub are required.
- The driver reports an oscillation state only after at least one horizontal or vertical value is returned by a refresh; normal device responses return both values.
