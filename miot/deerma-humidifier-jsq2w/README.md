# Deerma Humidifier JSQ2W

SmartThings Edge LAN driver for the Xiaomi/Deerma MIoT humidifier model `deerma.humidifier.jsq2w`.

## Protocol Decision

- Protocol: MIoT
- Model: `deerma.humidifier.jsq2w`
- specModel: `deerma-jsq2w`
- URN: `urn:miot-spec-v2:device:humidifier:0000A00E:deerma-jsq2w:2`
- Basis: python-miio `AirHumidifierJsqs` supports this model as a MIoT device; the exact MIoT spec confirms the mapped properties below.

## Exposed Capabilities

- `switch`
- `temperatureMeasurement`
- `relativeHumidityMeasurement`
- `concertmirror08464.deermaHumidifierJsq2wControls`
- `concertmirror08464.deermaHumidifierJsq2wStats`
- `refresh`

## MIoT Mapping

| Feature | Access | MIoT Key | SmartThings |
|---|---:|---|---|
| Power | RW | `siid=2`, `piid=1` | `switch` |
| Fault | R | `siid=2`, `piid=2`; `0=noFaults`, `1=insufficientWater`, `2=waterSeparation` | `deermaHumidifierJsq2wStats.fault` |
| Fan level | RW | `siid=2`, `piid=5`; `1=level1`, `2=level2`, `3=level3`, `4=level4` | `deermaHumidifierJsq2wControls.fanLevel` |
| Target humidity | RW | `siid=2`, `piid=6`; 40..70 %, step 1 | `deermaHumidifierJsq2wControls.targetHumidity` |
| Status | R | `siid=2`, `piid=7`; `1=idle`, `2=busy` | `deermaHumidifierJsq2wStats.status` |
| Mode | RW | `siid=2`, `piid=8`; `0=none`, `1=constantHumidity` | `deermaHumidifierJsq2wControls.mode` |
| Relative humidity | R | `siid=3`, `piid=1`; % | `relativeHumidityMeasurement` |
| Temperature | R | `siid=3`, `piid=7`; C | `temperatureMeasurement` |
| Alarm / buzzer | RW | `siid=5`, `piid=1` | `deermaHumidifierJsq2wControls.alarm` |
| Indicator light | RW | `siid=6`, `piid=1` | `deermaHumidifierJsq2wControls.indicatorLight` |
| Tank detected | R | `siid=7`, `piid=1` | `deermaHumidifierJsq2wStats.tankFilled` |
| Water shortage | R | `siid=7`, `piid=2` | `deermaHumidifierJsq2wStats.waterShortageFault` |
| Overwet protection | RW | `siid=7`, `piid=6` | `deermaHumidifierJsq2wControls.overwetProtect` |

Child lock is not exposed because the exact JSQ2W MIoT spec does not include a child-lock property.
