# Mijia Smart Air Purifier Elite

SmartThings Edge LAN driver for the Xiaomi MIoT air purifier model `xiaomi.airp.meb2`.

## Protocol Decision

- Protocol: MIoT
- Model: `xiaomi.airp.meb2`
- specModel: `xiaomi-meb2`
- URN: `urn:miot-spec-v2:device:air-purifier:0000A007:xiaomi-meb2:1:0000D050`
- Basis: Exact MIoT spec defines the local Elite air-purifier contract, and model docs identify `xiaomi.airp.meb2` as the Korea Wi-Fi Mijia Smart Air Purifier Elite.

## Exposed Capabilities

- `switch`
- `concertmirror08464.airPurifierEliteControls`
- `dustSensor`
- `temperatureMeasurement`
- `relativeHumidityMeasurement`
- `filterState`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Air purifier mode | RW | `siid=2`, `piid=4`, `0=auto`, `1=sleep`, `2=favorite`, `3=manual` | `airPurifierEliteControls.airPurifierMode` |
| Fan level | RW | `siid=2`, `piid=5`, `1=level1`, `2=level2`, `3=level3` | `airPurifierEliteControls.fanLevel` |
| Plasma | RW | `siid=2`, `piid=6` | `airPurifierEliteControls.plasma` |
| UV | RW | `siid=2`, `piid=7` | `airPurifierEliteControls.uv` |
| Humidity | R | `siid=3`, `piid=1`, `%` | `relativeHumidityMeasurement` |
| PM2.5 | R | `siid=3`, `piid=4`, `ug/m3` | `dustSensor.fineDustLevel` |
| Temperature | R | `siid=3`, `piid=7`, `C` | `temperatureMeasurement` |
| PM10 | R | `siid=3`, `piid=8`, `ug/m3` | `dustSensor.dustLevel` |
| Filter life | R | `siid=4`, `piid=1`, `%` | `filterState.filterLifeRemaining` |
| Buzzer | RW | `siid=6`, `piid=1` | `airPurifierEliteControls.buzzer` |
| Child lock | RW | `siid=8`, `piid=1` | `airPurifierEliteControls.childLock` |
| Display brightness | RW | `siid=13`, `piid=2`, `0=off`, `1=bright`, `2=brightest` | `airPurifierEliteControls.displayBrightness` |

Not exposed: device fault, air quality enum, filter used time, reset filter action, favorite level, display temperature unit, custom diagnostic services, AQI heartbeat, RFID data, and toggle actions are secondary, diagnostic, metadata, or shortcut values.
