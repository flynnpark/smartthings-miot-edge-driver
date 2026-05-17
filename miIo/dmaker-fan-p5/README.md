# Mi Smart Standing Fan 1X

SmartThings Edge LAN driver for one miIO model: `dmaker.fan.p5`.

## Protocol decision

- Protocol: miIO
- Model: `dmaker.fan.p5`
- Spec model: `dmaker-p5`
- URN: none recorded for this classic miIO mapping
- Basis: python-miio `FanP5` lists the exact model with classic `get_prop` and `s_*` commands. openHAB documents `dmaker.fan.p5` as Mi Smart Standing Fan 1X.

## Exposed capabilities

- `switch`: power
- `fanSpeed`: fan speed, 0-100
- `fanOscillationMode`: horizontal oscillation, `off` / `horizontal`
- `concertmirror08464.xiaomiFanControls`
  - `fanMode`: `normal` / `nature`
  - `indicatorLight`: 표시등, `off` / `on`
  - `buzzer`: 부저음, `off` / `on`
  - `childLock`: 차일드락, `off` / `on`
- `refresh`

## miIO mapping

Read via `get_prop`:

- `power`, read, boolean on/off
- `mode`, read, `normal` / `nature`
- `speed`, read, `0..100`
- `roll_enable`, read, horizontal oscillation on/off
- `roll_angle`, read, not exposed
- `time_off`, read, not exposed
- `light`, read, indicator light on/off
- `beep_sound`, read, buzzer on/off
- `child_lock`, read, child lock on/off

Write methods:

- `s_power`, write, boolean on/off
- `s_mode`, write, `normal` / `nature`
- `s_speed`, write, `0..100`
- `s_roll`, write, horizontal oscillation on/off
- `s_light`, write, indicator light on/off
- `s_sound`, write, buzzer on/off
- `s_lock`, write, child lock on/off

