# Xiaomi Smart Standing Fan 2 Pro

SmartThings Edge LAN driver for one MIoT model: `dmaker.fan.p33`.

## Protocol decision

- Protocol: MIoT
- Model: `dmaker.fan.p33`
- Spec model: `dmaker-p33`
- URN: `urn:miot-spec-v2:device:fan:0000A005:dmaker-p33:1`
- Basis: python-miio `FanMiot` lists exact model `dmaker.fan.p33`; a user report identifies Xiaomi Smart Standing Fan 2 Pro as `dmaker.fan.p33`; MIoT spec v1 confirms the core siid/piid layout.

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
- `piid=2` fan level bucket `1..4`, read/write, not exposed separately
- `piid=3` mode, read/write, `0=normal`, `1=nature`
- `piid=4` horizontal swing, read/write
- `piid=5` horizontal angle `30/60/90/120/140`, read/write, not exposed
- `piid=6` status/speed `1..100`, read in spec; python-miio maps it as writable fan speed

Off delay time service `siid=3`:

- `piid=1` power-off countdown `0..480` minutes, read/write, not exposed

Indicator light service `siid=4`:

- `piid=1` indicator light, read/write

Alarm service `siid=5`:

- `piid=1` buzzer/alarm, read/write

Motor controller service `siid=6`:

- `piid=1` motor control `0=none`, `1=left`, `2=right`, write only, not exposed
- `piid=2` fault, read only diagnostic value, not exposed

Physical controls locked service `siid=7`:

- `piid=1` child lock, read/write
