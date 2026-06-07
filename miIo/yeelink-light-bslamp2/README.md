# Mi Bedside Lamp 2

SmartThings Edge LAN driver for the Xiaomi/miIO light model `yeelink.light.bslamp2`.

## Protocol Decision

- Protocol: miIO
- Model: `yeelink.light.bslamp2`
- Basis: `python-miio` lists `yeelink.light.bslamp2` in the Yeelight miIO integration and the Xiaomi Mi Bedside Lamp 2 manual identifies `model=yeelink.light.bslamp2`; the MIoT spec records the equivalent power, brightness, color temperature, and RGB color contract.

## Exposed Capabilities

- `switch`
- `switchLevel`
- `colorTemperature`
- `colorControl`
- `refresh`

## miIO Mapping

| Feature | Access | miIO Key | SmartThings |
|---|---:|---|---|
| Power | RW | `power`, `set_power` with `on` / `off` | `switch` |
| Brightness | RW | `bright`, `set_bright`; 1..100 % | `switchLevel` |
| Color temperature | RW | `ct`, `set_ct_abx`; 1700..6500 K | `colorTemperature` |
| Color | RW | `rgb`, `set_rgb` | `colorControl` |

Not exposed: scenes, brightness delta, color temperature delta, developer mode, default-state setting, name setting, and internal Yeelight app settings because they are auxiliary controls rather than core SmartThings light controls.
