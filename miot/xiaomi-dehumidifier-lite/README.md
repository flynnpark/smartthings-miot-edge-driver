# Xiaomi Dehumidifier Lite

SmartThings Edge LAN driver for the Xiaomi MIoT dehumidifier model `xiaomi.derh.lite`.

## Protocol Decision

- Protocol: MIoT
- Model: `xiaomi.derh.lite`
- specModel: `xiaomi-lite`
- URN: `urn:miot-spec-v2:device:dehumidifier:0000A02D:xiaomi-lite:1`
- Basis: hass-xiaomi-miot documents MIoT local host/token support for devices using miot-spec, XiaomiHumidifier issue #4 reports `xiaomi.derh.lite` working when added to a MIoT model list, and Xiaomi product documentation confirms Mi Home control, smart/sleep/clothes drying modes, display brightness, child lock, notification sound, water-full/tank behavior, temperature, and humidity. The exact MIoT spec confirms the mapped properties below.

`xiaomi.derh.13l` / specModel `xiaomi-13l` is a separate model/spec and is not included in this one-model driver.

## Exposed Capabilities

- `switch`
- `relativeHumidityMeasurement`
- `temperatureMeasurement`
- `concertmirror08464.xiaomiDehumidifierLiteControls`
- `concertmirror08464.xiaomiDehumidifierLiteStatus`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Fault | R | `siid=2`, `piid=2`; `0=noFaults`, `1=waterFull`, `2=tempHumError`, `3=copperPipeTempError`, `4=communicationFailure`, `5=filterClean`, `6=defrost`, `7=motorStuck`, `8=overloadProtect`, `9=lackOfRefrigerant` | `xiaomiDehumidifierLiteStatus.fault` |
| Water tank status | R | derived from `siid=2`, `piid=2`; `1=waterFull`, otherwise `normal` | `xiaomiDehumidifierLiteStatus.tankStatus` |
| Filter status | R | derived from `siid=2`, `piid=2`; `5=filterClean`, otherwise `normal` | `xiaomiDehumidifierLiteStatus.filterStatus` |
| Mode | RW | `siid=2`, `piid=3`; `0=smart`, `1=sleep`, `2=clothesDrying` | `xiaomiDehumidifierLiteControls.mode` |
| Target humidity | RW | `siid=2`, `piid=5`; 40..70 %, step 1 | `xiaomiDehumidifierLiteControls.targetHumidity` |
| Relative humidity | R | `siid=3`, `piid=1`; % | `relativeHumidityMeasurement` |
| Temperature | R | `siid=3`, `piid=2`; celsius | `temperatureMeasurement` |
| Alarm / buzzer | RW | `siid=4`, `piid=1` | `xiaomiDehumidifierLiteControls.alarm` |
| Indicator light on | RW | `siid=5`, `piid=1` | `xiaomiDehumidifierLiteControls.indicatorLight=off` |
| Indicator light mode | RW | `siid=5`, `piid=2`; `1=dim`, `2=bright` | `xiaomiDehumidifierLiteControls.indicatorLight` |
| Child lock | RW | `siid=6`, `piid=1` | `xiaomiDehumidifierLiteControls.childLock` |
| Dry after off | RW | `siid=7`, `piid=1` | `xiaomiDehumidifierLiteControls.dryAfterOff` |
| Reset filter | Action | `siid=7`, `aiid=3` | `xiaomiDehumidifierLiteControls.resetFilter` |

Not exposed: delay timer, dry-left-time, warming-up state, toggle action, loop-mode action, and internal diagnostic values because they are auxiliary/internal values rather than core controls or sensors for this port.
