# Mijia Mist-Free Humidifier 3 Pro

SmartThings Edge LAN driver for the Xiaomi MIoT humidifier model `xiaomi.humidifier.airmx`.

## Setup

This LAN driver needs the device Xiaomi token and local IP address. Use [Xiaomi Cloud Tokens Extractor](https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor) with the same Mi Home server region, then enter the device `token` and `ip` in SmartThings preferences.

## Protocol Decision

- Protocol: MIoT
- Model: `xiaomi.humidifier.airmx`
- specModel: `xiaomi-3pro`
- URN: `urn:miot-spec-v2:device:humidifier:0000A00E:xiaomi-3pro:1:0000D061`
- Basis: model docs identify `xiaomi.humidifier.airmx` as Mijia Mist-Free Humidifier 3 Pro. hass-xiaomi-miot documents LAN MIoT host/token support for miot-spec devices. The exact MIoT spec confirms the mapped properties below.

## Exposed Capabilities

- `switch`
- `temperatureMeasurement`
- `relativeHumidityMeasurement`
- `filterState`
- `concertmirror08464.xiaomiHumidifier3ProControls`
- `concertmirror08464.xiaomiHumidifier3ProStats`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Fault | R | `siid=2`, `piid=2`; `0=noFaults`, `1=pumpFault`, `2=lowWater`, `3=pumpLowWater` | `xiaomiHumidifier3ProStats.fault` |
| Water status | R | derived from `siid=2`, `piid=2`; low-water faults become `lowWater` | `xiaomiHumidifier3ProStats.waterStatus` |
| Water level | R | `siid=2`, `piid=11`; 0..100 %, step 1 | `xiaomiHumidifier3ProStats.waterLevel` |
| Mode | RW | `siid=2`, `piid=3`; `0=constantHumidity`, `1=strong`, `2=sleep`, `3=airDry`, `4=clean`, `5=descale`, `6=none` | `xiaomiHumidifier3ProControls.mode` |
| Target humidity | RW | `siid=2`, `piid=5`; 40..70 %, step 1 | `xiaomiHumidifier3ProControls.targetHumidity` |
| Automatic air drying | RW | `siid=2`, `piid=12` | `xiaomiHumidifier3ProControls.automaticAirDrying` |
| Over-wet protection | RW | `siid=2`, `piid=14` | `xiaomiHumidifier3ProControls.overwetProtect` |
| Relative humidity | R | `siid=3`, `piid=1`; % | `relativeHumidityMeasurement` |
| Temperature | R | `siid=3`, `piid=2`; C | `temperatureMeasurement` |
| Child lock | RW | `siid=11`, `piid=1` | `xiaomiHumidifier3ProControls.childLock` |
| Alarm / buzzer | RW | `siid=14`, `piid=1` | `xiaomiHumidifier3ProControls.alarm` |
| Indicator light | RW | `siid=15`, `piid=1` | `xiaomiHumidifier3ProControls.indicatorLight` |
| Indicator mode | RW | `siid=15`, `piid=2`; `1=auto`, `2=manual` | `xiaomiHumidifier3ProControls.indicatorMode` |
| Indicator brightness | RW | `siid=15`, `piid=3`; 1..5, step 1 | `xiaomiHumidifier3ProControls.indicatorBrightness` |
| Filter life | R | `siid=18`, `piid=1`; 0..100 % | `filterState.filterLifeRemaining` |
| Reset filter life | Action | `siid=18`, `aiid=1` | `filterState.resetFilter` |

Not exposed: delay timer, auto alarm off, auto lights off, remaining air-dry time, cleaning/descaling/washing internals, and reminder-test values because they are auxiliary maintenance values rather than core controls or sensors for this port.
