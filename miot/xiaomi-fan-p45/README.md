# Xiaomi Smart Tower Fan 2

SmartThings Edge LAN driver for one MIoT model: `xiaomi.fan.p45`.

## Protocol decision

- Protocol: MIoT
- Model: `xiaomi.fan.p45`
- Spec model: `xiaomi-p45`
- URN: `urn:miot-spec-v2:device:fan:0000A005:xiaomi-p45:1:0000D062`
- Basis: homebridge-miot lists `xiaomi.fan.p45` as Xiaomi Smart Tower Fan 2 under a MIoT plugin; Xiaomi Korea product page confirms direct/natural/sleep modes, 100 speed levels, 150-degree oscillation, app control, child lock, and indicator behavior; MIoT spec v1 confirms the core siid/piid layout.

## Exposed capabilities

- `switch`: power
- `fanSpeed`: stepless fan level, 1-100
- `fanOscillationMode`: horizontal oscillation, `off` / `horizontal`
- `concertmirror08464.xiaomiTowerFan2Controls`
  - `fanMode`: `normal` / `nature` / `sleep`
  - `indicatorLight`: 표시등, `off` / `on`
  - `buzzer`: 부저음, `off` / `on`
  - `childLock`: 차일드락, `off` / `on`
- `refresh`

## MIoT mapping

Fan service `siid=2`:

- `piid=1` power, read/write
- `piid=2` fault, read only diagnostic value, not exposed
- `piid=3` mode, read/write, `0=normal`, `1=nature`, `2=sleep`
- `piid=4` gear fan level `1..4`, read/write, not exposed separately
- `piid=5` stepless fan level `1..100`, read/write
- `piid=6` horizontal swing, read/write
- `piid=7` horizontal angle `30/60/90/120/150`, read/write, not exposed
- `aiid=3` toggle, not exposed
- `aiid=4` turn left, not exposed
- `aiid=5` turn right, not exposed

Indicator light service `siid=5`:

- `piid=1` indicator light, read/write

Alarm service `siid=7`:

- `piid=1` buzzer/alarm, read/write

Physical controls locked service `siid=11`:

- `piid=1` child lock, read/write

Delay service `siid=12`:

- `piid=1` delay on/off, read/write, not exposed
- `piid=2` delay time `0..480` minutes, read/write, not exposed
- `piid=3` delay remain time `0..480` minutes, read only, not exposed

Xiaomi dm-service `siid=13`:

- `piid=1` start left, write only, not exposed
- `piid=2` start right, write only, not exposed
- `piid=3..7` natural wind customization strings, read/write, not exposed
