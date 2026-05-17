# Mijia DC Inverter Tower Fan 2

SmartThings Edge LAN driver for one MIoT model: `dmaker.fan.p45`.

## Protocol decision

- Protocol: MIoT
- Model: `dmaker.fan.p45`
- Spec model: `dmaker-p45`
- URN: `urn:miot-spec-v2:device:fan:0000A005:dmaker-p45:1`
- Basis: python-miio `FanMiot` lists the exact model with MIoT siid/piid mapping. MIoT spec v1 confirms power, fan level, mode, horizontal swing, angle, off delay, indicator light, buzzer, child lock, and stepless fan speed. Model docs identify `dmaker.fan.p45` as Mijia DC Inverter Tower Fan 2.

## Exposed capabilities

- `switch`: power
- `fanSpeed`: stepless fan level, 1-100
- `fanOscillationMode`: horizontal oscillation, `off` / `horizontal`
- `concertmirror08464.xiaomiTowerFan2Controls`
  - `fanMode`: `normal` / `nature` / `sleep`
  - `indicatorLight`: display/indicator light, `off` / `on`
  - `buzzer`: buzzer, `off` / `on`
  - `childLock`: child lock, `off` / `on`
- `refresh`

## MIoT mapping

Fan service `siid=2`:

- `piid=1` power, read/write
- `piid=2` fan level `1..4`, read/write, not exposed separately
- `piid=3` mode, read/write, `0=normal`, `1=nature`, `2=sleep`
- `piid=4` horizontal swing, read/write
- `piid=5` horizontal angle `30/60/90/120/150`, read/write, not exposed
- `aiid=1` toggle, not exposed
- `aiid=2` turn left, not exposed
- `aiid=3` turn right, not exposed

Off delay service `siid=3`:

- `piid=1` off delay time `0..480` minutes, read/write, not exposed

Indicator light service `siid=4`:

- `piid=1` indicator light, read/write

Alarm service `siid=5`:

- `piid=1` buzzer/alarm, read/write

Physical controls locked service `siid=7`:

- `piid=1` child lock, read/write

Dmaker service `siid=8`:

- `piid=1` stepless fan level `1..100`, read/write
- `piid=3` start left, write only, not exposed
- `piid=4` start right, write only, not exposed
- `piid=5..9` natural wind customization strings, read/write, not exposed
