# Xiaomi Mi Smart Pedestal Fan P10

SmartThings Edge LAN driver for one MIoT model: `dmaker.fan.p10`.

## Protocol decision

- Protocol: MIoT
- Model: `dmaker.fan.p10`
- Spec model: `dmaker-p10`
- URN: `urn:miot-spec-v2:device:fan:0000A005:dmaker-p10:2`
- Basis: python-miio `FanMiot` lists `dmaker.fan.p10` with this MIoT property layout; MIoT spec v2 confirms the same core siid/piid mapping.

## Exposed capabilities

- `switch`: power
- `fanSpeed`: fan speed, 1-100
- `fanOscillationMode`: horizontal oscillation, `off` / `horizontal`
- `concertmirror08464.xiaomiFanControls`
  - `fanMode`: `normal` / `nature`
  - `indicatorLight`: 표시등, `off` / `on`
  - `buzzer`: 부저음, `off` / `on`
  - `childLock`: 차일드락, `off` / `on`
- `refresh`

## MIoT mapping

Fan service `siid=2`:

- `piid=1` power, read/write
- `piid=2` fan level bucket, read only
- `piid=3` mode, read/write, `0=normal`, `1=nature`
- `piid=4` horizontal swing, read/write
- `piid=5` swing angle, read only in this driver
- `piid=6` power-off countdown, read only in this driver
- `piid=7` indicator light, read/write
- `piid=8` buzzer, read/write
- `piid=9` set move, action-like direction value, not exposed
- `piid=10` fan speed, read/write, `1..100`

Physical controls locked service `siid=3`:

- `piid=1` child lock, read/write
