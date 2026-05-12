# Xiaomi Smart Air Purifier 4 Compact

SmartThings Edge LAN driver for `zhimi.airp.cpa4`.

## Protocol

- Protocol: MIoT
- Model: `zhimi.airp.cpa4`
- Spec model: `zhimi-cpa4`
- URN: `urn:miot-spec-v2:device:air-purifier:0000A007:zhimi-cpa4:1`
- Evidence: python-miio issue #1550 reports working MIoT `get_property_by`/`set_properties` calls for this model; Xiaomi Korea product page identifies Xiaomi Smart Air Purifier 4 Compact as a Korea-market Mi Home air purifier; the exact MIoT spec was saved under `data/specs/air-purifier-zhimi-cpa4-v1.json`.

## MIoT Mapping

| Feature | MIoT key | Access | SmartThings capability |
| --- | --- | --- | --- |
| Power | `siid=2`, `piid=1` | read/write | `switch` |
| Mode | `siid=2`, `piid=4`, `0=Auto`, `1=Sleep`, `2=Favorite` | read/write | `concertmirror08464.zhimiAirPurifierThreeMode` |
| PM2.5 | `siid=3`, `piid=4`, `0..600 ug/m3` | read | `fineDustSensor` |
| Filter life | `siid=4`, `piid=1`, `0..100 %` | read | `filterState.filterLifeRemaining` |
| Buzzer | `siid=6`, `piid=1` | read/write | `concertmirror08464.xiaomiAp4cControls.buzzer` |
| Child lock | `siid=8`, `piid=1` | read/write | `concertmirror08464.xiaomiAp4cControls.childLock` |
| Screen brightness | `siid=13`, `piid=2`, `0=Close`, `1=Bright`, `2=Brightest` | read/write | `concertmirror08464.xiaomiAp4cControls.screenBrightness` |

The custom service favorite level (`siid=9`, `piid=11`) is intentionally not exposed as a direct control here because the primary mode contract is auto/sleep/favorite and existing user reports note mixed behavior around fan-level style commands on this compact model.
