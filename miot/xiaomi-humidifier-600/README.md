# Xiaomi Humidifier 600

SmartThings Edge LAN driver for the Xiaomi MIoT humidifier model `xiaomi.humidifier.600`.

## Protocol Decision

- Protocol: MIoT
- Model: `xiaomi.humidifier.600`
- specModel: `xiaomi-600`
- URN: `urn:miot-spec-v2:device:humidifier:0000A00E:xiaomi-600:2:0000D061`
- Basis: the exact MIoT spec confirms the local MIoT service/property contract and matches the existing Xiaomi Humidifier 4lite core mapping.

## Exposed Capabilities

- `switch`
- `relativeHumidityMeasurement`
- `filterState`
- `concertmirror08464.xiaomiHumidifier4liteControls`
- `concertmirror08464.xiaomiHumidifier4liteStats`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Fault | R | `siid=2`, `piid=2`; `0=noFaults`, `1=motorFault`, `2=pumpFault`, `3=pumpFail`, `4=lowWater` | `xiaomiHumidifier4liteStats.fault` |
| Water tank status | R | derived from `siid=2`, `piid=2`; `4=lowWater`, otherwise `normal` | `xiaomiHumidifier4liteStats.waterStatus` |
| Mode | RW | `siid=2`, `piid=3`; `0=constantHumidity`, `1=sleep`, `2=strong`, `3=airDry` | `xiaomiHumidifier4liteControls.mode` |
| Target humidity | RW | `siid=2`, `piid=5`; 40..70 %, step 1 | `xiaomiHumidifier4liteControls.targetHumidity` |
| Over-wet protection | RW | `siid=2`, `piid=11` | `xiaomiHumidifier4liteControls.overwetProtect` |
| Relative humidity | R | `siid=3`, `piid=1`; % | `relativeHumidityMeasurement` |
| Filter life | R | `siid=4`, `piid=1`; 0..100 % | `filterState.filterLifeRemaining` |
| Reset filter life | Action | `siid=4`, `aiid=1` | `filterState.resetFilter` |
| Screen on | RW | `siid=6`, `piid=1` | `xiaomiHumidifier4liteControls.screenBrightness=off` |
| Screen brightness | RW | `siid=6`, `piid=2`; `0=dim`, `1=normal` | `xiaomiHumidifier4liteControls.screenBrightness` |
| Alarm / buzzer | RW | `siid=7`, `piid=1` | `xiaomiHumidifier4liteControls.alarm` |
| Child lock | RW | `siid=8`, `piid=1` | `xiaomiHumidifier4liteControls.childLock` |

Not exposed: delay timer, air-dry remaining time, clean-time, write-only filter level, filter-clean status, and loop/self-clean actions because they are auxiliary/internal values rather than core SmartThings controls or sensors for this port.
