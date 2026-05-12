# Xiaomi Fan 1C

SmartThings Edge LAN driver for one MIoT model: `dmaker.fan.1c`.

## Protocol decision

- Protocol: MIoT
- Model: `dmaker.fan.1c`
- Spec model: `dmaker-1c`
- URN: `urn:miot-spec-v2:device:fan:0000A005:dmaker-1c:1`
- Basis: python-miio `FanMiot` includes a Fan1C mapping; MIoT spec v1 confirms the same core siid/piid mapping.

## Exposed capabilities

- `switch`: power
- `fanOscillationMode`: horizontal oscillation, `off` / `horizontal`
- `concertmirror08464.xiaomiFan1cControls`
  - `fanLevel`: `1..3`
  - `fanMode`: `normal` / `sleep`
  - `indicatorLight`: 표시등, `off` / `on`
  - `buzzer`: 부저음, `off` / `on`
  - `childLock`: 차일드락, `off` / `on`
- `refresh`

## MIoT mapping

Fan service `siid=2`:

- `piid=1` power, read/write
- `piid=2` fan level, read/write, `1..3`
- `piid=3` horizontal swing, read/write
- `piid=7` mode, read/write, `0=normal`, `1=sleep`
- `piid=10` power-off countdown, read/write, not exposed
- `piid=11` buzzer, read/write
- `piid=12` indicator light, read/write

Physical controls locked service `siid=3`:

- `piid=1` child lock, read/write
