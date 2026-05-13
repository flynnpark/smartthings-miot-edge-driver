# Mijia Smart Air Purifier 5 Pro

SmartThings Edge LAN driver for one MIoT model: `xiaomi.airp.va5`.

## Protocol decision

- Protocol: MIoT
- Model: `xiaomi.airp.va5`
- Spec model: `xiaomi-va5`
- URN: `urn:miot-spec-v2:device:air-purifier:0000A007:xiaomi-va5:2:0000D050`
- Basis: hass-xiaomi-miot documents MIoT LAN host/token support, model docs identify `xiaomi.airp.va5` as Mijia Smart Air Purifier 5 Pro, and the exact MIoT spec confirms the core siid/piid layout.

## Exposed capabilities

- `switch`: power
- `concertmirror08464.airPurifier5ProControls`
  - `airPurifierMode`: `auto` / `sleep` / `favorite` / `none`
  - `fanLevel`: `level1` / `level2` / `level3`
  - `screen`: display screen, `off` / `on`
  - `screenBrightness`: `dim` / `normal`
  - `buzzer`: `off` / `on`
  - `childLock`: `off` / `on`
- `dustSensor`: PM2.5 and PM10 density
- `formaldehydeMeasurement`: HCHO density
- `temperatureMeasurement`: temperature
- `relativeHumidityMeasurement`: humidity
- `filterState`: filter life remaining
- `refresh`

## MIoT mapping

Air purifier service `siid=2`:

- `piid=1` power, read/write
- `piid=2` fault, read only diagnostic value, not exposed
- `piid=3` mode, read/write, `0=auto`, `3=sleep`, `5=favorite`, `6=none`
- `piid=4` fan level, read/write, `0=level1`, `1=level2`, `2=level3`
- `piid=6` UV, read/write, not exposed in this driver

Environment service `siid=3`:

- `piid=1` humidity `0..100%`, read only
- `piid=2` temperature `-30..100 C`, read only
- `piid=3` air quality enum, read only, not exposed
- `piid=4` PM2.5 `0..600 ug/m3`, read only
- `piid=5` PM10 `0..100 ug/m3`, read only
- `piid=6` HCHO `0..0.5 mg/m3`, read only
- `piid=9` PM1 `0..600 ug/m3`, read only, not exposed

Filter service `siid=4`:

- `piid=1` filter life `0..100%`, read only
- `piid=2` filter left time, read only, not exposed
- `piid=3` filter used time, read only, not exposed

Screen service `siid=6`:

- `piid=1` display screen, read/write
- `piid=2` brightness, read/write, `0=dim`, `1=normal`

Alarm service `siid=7`:

- `piid=1` buzzer/alarm, read/write

Physical controls locked service `siid=8`:

- `piid=1` child lock, read/write

Favorite, self-check, filter tag, custom, and diagnostics services contain fine-tuning, service actions, internal status, and metadata. They are not exposed as core SmartThings controls or sensors.
