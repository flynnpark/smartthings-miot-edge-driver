# SmartThings Edge Drivers for Xiaomi Devices

Installation channel (`wonjj_miot`): [open SmartThings channel](https://bestow-regional.api.smartthings.com/invite/r3MyzkOpOz2p)

SmartThings Edge LAN drivers for Xiaomi ecosystem devices using the MIoT and miIO protocols.

Each driver targets one exact Xiaomi model id. Do not choose by retail product name alone because Xiaomi often reuses the same product name for different hardware models.

## Choosing a Driver

1. Check the Xiaomi model id from Mi Home, Xiaomi Cloud Tokens Extractor, or the device information page.
2. Find the exact same value in the `Device model` column below.
3. Install the matching `SmartThings driver name` from the `wonjj_miot` channel.
4. If several rows have the same `Product name`, use `Device model` as the deciding value.

The `SmartThings driver name` column is the name shown in the SmartThings Edge channel. The `Driver folder` column is included for source review and issue reports.

## Requirements

These LAN drivers need the Xiaomi device token and local IP address. Use [Xiaomi Cloud Tokens Extractor](https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor), select the same Xiaomi server region used in Mi Home, then copy the device `token` and `ip` into the SmartThings device preferences.

## Installation

1. Open the installation channel above and enroll the SmartThings location.
2. Install the SmartThings driver whose `Device model` exactly matches the Xiaomi model id.
3. Add a device in the SmartThings app.
4. Enter `ipAddress`, `token`, and `pollingInterval` in device preferences.
5. Toggle `createDev` when using the LAN manual creation pattern.

## Drivers

Supported drivers are grouped by protocol and device type.

### MIoT Air Purifiers

| Driver folder | Device model | Product name | SmartThings driver name |
|---------------|--------------|--------------|-------------------------|
| `miot/zhimi-air-purifier-mb5` | `zhimi.airpurifier.mb5` | Xiaomi Smart Air Purifier 4 | `Zhimi Air Purifier MB5` |
| `miot/zhimi-air-purifier-airp-mb5` | `zhimi.airp.mb5` | Xiaomi Smart Air Purifier 4 | `Xiaomi Smart Air Purifier 4` |
| `miot/xiaomi-air-purifier-mb5` | `xiaomi.airp.mb5` | Mijia Smart Air Purifier 6 | `Mijia Smart Air Purifier 6` |
| `miot/xiaomi-air-purifier-mb6` | `xiaomi.airp.mb6` | Mijia Smart Air Purifier MAX | `Mijia Smart Air Purifier MAX` |
| `miot/xiaomi-air-purifier-meb2` | `xiaomi.airp.meb2` | Mijia Smart Air Purifier Elite | `Mijia Air Purifier MEB2` |
| `miot/xiaomi-air-purifier-va5` | `xiaomi.airp.va5` | Mijia Smart Air Purifier 5 Pro | `Mijia Smart Air Purifier 5 Pro` |
| `miot/zhimi-air-purifier-mb5a` | `zhimi.airp.mb5a` | Xiaomi Smart Air Purifier 4 | `Zhimi Air Purifier MB5A` |
| `miot/zhimi-air-purifier-va2` | `zhimi.airp.va2` | Xiaomi Air Purifier Pro H | `Zhimi Air Purifier VA2` |
| `miot/zhimi-air-purifier-vb4` | `zhimi.airp.vb4` | Xiaomi Air Purifier Pro 4 | `Zhimi Air Purifier VB4` |
| `miot/zhimi-air-purifier-rmb1` | `zhimi.airp.rmb1` | Xiaomi Smart Air Purifier 4 Lite | `Zhimi Air Purifier RMB1` |
| `miot/zhimi-air-purifier-rma1` | `zhimi.airpurifier.rma1` | Xiaomi Smart Air Purifier 4 Lite | `Zhimi Air Purifier RMA1` |
| `miot/zhimi-air-purifier-rma2` | `zhimi.airpurifier.rma2` | Xiaomi Smart Air Purifier 4 Lite | `Zhimi Air Purifier RMA2` |
| `miot/zhimi-air-purifier-za1` | `zhimi.airpurifier.za1` | Smartmi Air Purifier | `Zhimi Air Purifier ZA1` |
| `miot/zhimi-air-purifier-meb1` | `zhimi.airp.meb1` | Xiaomi Smart Air Purifier Elite | `Xiaomi Smart Air Purifier Elite` |
| `miot/zhimi-air-purifier-cpa4` | `zhimi.airp.cpa4` | Xiaomi Smart Air Purifier 4 Compact | `Xiaomi Smart Air Purifier 4 Compact` |
| `miot/zhimi-air-purifier-mb4` | `zhimi.airpurifier.mb4` | Xiaomi Mi Air Purifier 3C | `Zhimi Air Purifier MB4` |
| `miot/zhimi-air-purifier-mb4a` | `zhimi.airp.mb4a` | Xiaomi Mi Air Purifier 3C v2 | `Zhimi Air Purifier MB4A` |
| `miot/zhimi-air-purifier-ma4` | `zhimi.airpurifier.ma4` | Xiaomi Mi Air Purifier 3 | `Zhimi Air Purifier MA4` |
| `miot/zhimi-air-purifier-mb3` | `zhimi.airpurifier.mb3` | Xiaomi Mi Air Purifier 3H | `Zhimi Air Purifier MB3` |
| `miot/zhimi-air-purifier-mb3a` | `zhimi.airpurifier.mb3a` | Xiaomi Mi Air Purifier 3H v2 | `Zhimi Air Purifier MB3A` |
| `miot/zhimi-air-purifier-airp-mb3a` | `zhimi.airp.mb3a` | Xiaomi Mi Air Purifier 3H v2 | `Zhimi Air Purifier AIRP MB3A` |
| `miot/zhimi-air-purifier-va1` | `zhimi.airpurifier.va1` | Xiaomi Mi Air Purifier Pro H CN | `Zhimi Air Purifier VA1` |
| `miot/zhimi-air-purifier-vb2` | `zhimi.airpurifier.vb2` | Xiaomi Mi Air Purifier Pro H | `Zhimi Air Purifier VB2` |

### MIoT Humidifiers

| Driver folder | Device model | Product name | SmartThings driver name |
|---------------|--------------|--------------|-------------------------|
| `miot/zhimi-humidifier-ca4` | `zhimi.humidifier.ca4` | Smartmi Evaporative Humidifier 2 | `Zhimi Humidifier CA4` |
| `miot/zhimi-humidifier-ca6` | `zhimi.humidifier.ca6` | Smartmi Evaporative Humidifier CA6 | `Zhimi Humidifier CA6` |
| `miot/deerma-humidifier-jsq5` | `deerma.humidifier.jsq5` | Xiaomi Mi Smart Antibacterial Humidifier S | `Deerma Humidifier JSQ5` |
| `miot/deerma-humidifier-jsq2w` | `deerma.humidifier.jsq2w` | Xiaomi Smart Humidifier 2 | `Deerma Humidifier JSQ2W` |
| `miot/xiaomi-humidifier-airmx` | `xiaomi.humidifier.airmx` | Mijia Mist-Free Humidifier 3 Pro | `Mijia Mist-Free Humidifier 3 Pro` |
| `miot/xiaomi-humidifier-p800` | `xiaomi.humidifier.p800` | Mijia Mist-Free Humidifier 3 (800) | `Xiaomi Humidifier P800` |
| `miot/xiaomi-humidifier-p1200` | `xiaomi.humidifier.p1200` | Mijia No-Fog Humidifier 3 1200 | `Xiaomi Humidifier P1200` |
| `miot/xiaomi-humidifier-3lite` | `xiaomi.humidifier.3lite` | Xiaomi Smart Humidifier 3 Lite | `Xiaomi Humidifier 3lite` |
| `miot/xiaomi-humidifier-4lite` | `xiaomi.humidifier.4lite` | Xiaomi Humidifier 4 Lite | `Xiaomi Humidifier 4lite` |
| `miot/xiaomi-humidifier-600` | `xiaomi.humidifier.600` | Xiaomi Humidifier 600 | `Xiaomi Humidifier 600` |

### MIoT Dehumidifiers

| Driver folder | Device model | Product name | SmartThings driver name |
|---------------|--------------|--------------|-------------------------|
| `miot/xiaomi-dehumidifier-lite` | `xiaomi.derh.lite` | Xiaomi Smart Dehumidifier Lite | `Xiaomi Dehumidifier Lite` |
| `miot/xiaomi-dehumidifier-13l` | `xiaomi.derh.13l` | Xiaomi Smart Dehumidifier 13L | `Xiaomi Dehumidifier 13L` |
| `miot/dmaker-dehumidifier-22l` | `dmaker.derh.22l` | Mijia Smart Dehumidifier 22L | `Mijia Dehumidifier 22L` |
| `miot/nwt-dehumidifier-312en` | `nwt.derh.312en` | NWT Dehumidifier 312EN | `NWT Dehumidifier 312EN` |

### MIoT Fans

| Driver folder | Device model | Product name | SmartThings driver name |
|---------------|--------------|--------------|-------------------------|
| `miot/dmaker-fan-1c` | `dmaker.fan.1c` | Mi Smart Standing Fan 1C | `Xiaomi Fan 1C` |
| `miot/dmaker-fan-p10` | `dmaker.fan.p10` | Mi Smart Standing Fan 2 | `Xiaomi Fan P10` |
| `miot/dmaker-fan-p11` | `dmaker.fan.p11` | Xiaomi Smart Fan V2 | `Xiaomi Smart Fan V2` |
| `miot/dmaker-fan-p15` | `dmaker.fan.p15` | Xiaomi Mi Smart Standing Fan Pro 4th Gen (ZLBPSP01XY) | `Mi Smart Standing Fan Pro` |
| `miot/dmaker-fan-p9` | `dmaker.fan.p9` | Mi Smart Tower Fan | `Mi Smart Tower Fan` |
| `miot/dmaker-fan-p39` | `dmaker.fan.p39` | Xiaomi Smart Tower Fan | `Xiaomi Smart Tower Fan` |
| `miot/dmaker-fan-p33` | `dmaker.fan.p33` | Xiaomi Smart Standing Fan 2 Pro | `Xiaomi Smart Standing Fan 2 Pro` |
| `miot/dmaker-fan-p18` | `dmaker.fan.p18` | Mi Smart Fan 2 | `Xiaomi Smart Standing Fan 2` |
| `miot/dmaker-fan-p220` | `dmaker.fan.p220` | Mijia Smart DC Inverter Circulating Standing Fan | `Mijia Fan P220` |
| `miot/dmaker-fan-p221` | `dmaker.fan.p221` | Mijia Smart DC Inverter Circulating Standing Fan Battery Edition | `Mijia Fan P221` |
| `miot/dmaker-fan-p28` | `dmaker.fan.p28` | Mijia Smart DC Inverter Circulating Fan Floor Type | `Mijia Fan P28` |
| `miot/dmaker-fan-p30` | `dmaker.fan.p30` | Xiaomi Smart Standing Fan 2 P30 | `Xiaomi Fan P30` |
| `miot/xiaomi-fan-2lite` | `xiaomi.fan.2lite` | Mi Smart Standing Fan 2 Lite | `Xiaomi Fan 2 Lite` |
| `miot/xiaomi-fan-p45` | `xiaomi.fan.p45` | Xiaomi Smart Tower Fan 2 | `Xiaomi Smart Tower Fan 2` |
| `miot/xiaomi-fan-p69` | `xiaomi.fan.p69` | Mijia Smart Desktop Air Circulation Fan | `Mijia Desktop Circulation Fan` |
| `miot/xiaomi-fan-p70` | `xiaomi.fan.p70` | Xiaomi BPLDS10DM Smart Desktop Air Circulation Fan | `Xiaomi Fan P70` |
| `miot/xiaomi-fan-p76` | `xiaomi.fan.p76` | Xiaomi Smart Standing Air Circulation Fan | `Xiaomi Fan P76` |
| `miot/xiaomi-fan-p90` | `xiaomi.fan.p90` | Mijia Smart Inverter Air Circulation Fan Pro | `Mijia Circulation Fan Pro` |
| `miot/pinlo-fan-fs1` | `pinlo.fan.fs1` | Plabson Slim Fan | `Plabson Slim Fan` |
| `miot/dmaker-fan-p45` | `dmaker.fan.p45` | Mijia DC Inverter Tower Fan 2 | `Mijia DC Inverter Tower Fan 2` |
| `miot/xiaomi-fan-p43` | `xiaomi.fan.p43` | Xiaomi Fan P43 | `Xiaomi Fan P43` |
| `miot/zhimi-fan-za4` | `zhimi.fan.za4` | Smartmi Standing Fan 2S | `Smartmi Standing Fan 2S` |
| `miot/zhimi-fan-za5` | `zhimi.fan.za5` | Smartmi Standing Fan 3 | `Smartmi Standing Fan 3` |

### MIoT Other Devices

| Driver folder | Device model | Product name | SmartThings driver name |
|---------------|--------------|--------------|-------------------------|
| `miot/xiaomi-fish-tank-m100` | `hfjh.fishbowl.m100` | Xiaomi Smart Fish Tank MYG100 | `Xiaomi Smart Fish Tank MYG100` |
| `miot/zhimi-heater-mc2` | `zhimi.heater.mc2` | Mi Smart Space Heater S | `Mi Smart Space Heater S` |
| `miot/qingping-air-monitor-lite` | `cgllc.airm.cgd1st` | Qingping Air Monitor Lite | `Qingping Air Monitor Lite2` |

### miIO Air Purifiers

| Driver folder | Device model | Product name | SmartThings driver name |
|---------------|--------------|--------------|-------------------------|
| `miIo/zhimi-air-purifier-mc1` | `zhimi.airpurifier.mc1` | Xiaomi Air Purifier 2S Global Version | `Zhimi Air Purifier MC1` |
| `miIo/zhimi-air-purifier-mc2` | `zhimi.airpurifier.mc2` | Xiaomi Air Purifier 2H | `Zhimi Air Purifier MC2` |
| `miIo/zhimi-air-purifier-v1` | `zhimi.airpurifier.v1` | Xiaomi Mi Air Purifier | `Zhimi Air Purifier V1` |
| `miIo/zhimi-air-purifier-v2` | `zhimi.airpurifier.v2` | Xiaomi Mi Air Purifier | `Zhimi Air Purifier V2` |
| `miIo/zhimi-air-purifier-v3` | `zhimi.airpurifier.v3` | Xiaomi Mi Air Purifier | `Zhimi Air Purifier V3` |
| `miIo/zhimi-air-purifier-v5` | `zhimi.airpurifier.v5` | Xiaomi Mi Air Purifier Pro | `Zhimi Air Purifier V5` |
| `miIo/zhimi-air-purifier-v6` | `zhimi.airpurifier.v6` | Xiaomi Mi Air Purifier Pro (AC-M3-CA) | `Zhimi Air Purifier V6` |
| `miIo/zhimi-air-purifier-v7` | `zhimi.airpurifier.v7` | Xiaomi Mi Air Purifier Pro V7 | `Zhimi Air Purifier V7` |
| `miIo/zhimi-air-purifier-m1` | `zhimi.airpurifier.m1` | Xiaomi Mi Air Purifier 2 Mini | `Zhimi Air Purifier M1` |
| `miIo/zhimi-air-purifier-m2` | `zhimi.airpurifier.m2` | Xiaomi Air Purifier 2 | `Zhimi Air Purifier M2` |
| `miIo/zhimi-air-purifier-ma1` | `zhimi.airpurifier.ma1` | Xiaomi Air Purifier 2S | `Zhimi Air Purifier MA1` |
| `miIo/zhimi-air-purifier-ma2` | `zhimi.airpurifier.ma2` | Xiaomi Air Purifier 2S | `Zhimi Air Purifier MA2` |
| `miIo/zhimi-air-purifier-sa1` | `zhimi.airpurifier.sa1` | Xiaomi Air Purifier S | `Zhimi Air Purifier SA1` |
| `miIo/zhimi-air-purifier-sa2` | `zhimi.airpurifier.sa2` | Xiaomi Air Purifier S2 | `Zhimi Air Purifier SA2` |

### miIO Humidifiers

| Driver folder | Device model | Product name | SmartThings driver name |
|---------------|--------------|--------------|-------------------------|
| `miIo/zhimi-humidifier-v1` | `zhimi.humidifier.v1` | Smartmi Evaporative Humidifier | `Zhimi Humidifier V1` |
| `miIo/zhimi-humidifier-ca1` | `zhimi.humidifier.ca1` | Smartmi Evaporative Humidifier 2 | `Zhimi Humidifier CA1` |
| `miIo/zhimi-humidifier-cb1` | `zhimi.humidifier.cb1` | Smartmi Air Humidifier 2 | `Zhimi Humidifier CB1` |
| `miIo/zhimi-humidifier-cb2` | `zhimi.humidifier.cb2` | Smartmi Air Humidifier 2 | `Zhimi Humidifier CB2` |

### miIO Fans

| Driver folder | Device model | Product name | SmartThings driver name |
|---------------|--------------|--------------|-------------------------|
| `miIo/zhimi-fan-sa1` | `zhimi.fan.sa1` | Zhimi Fan SA1 | `Zhimi Fan SA1` |
| `miIo/zhimi-fan-za1` | `zhimi.fan.za1` | Smartmi Inverter Pedestal Fan | `Zhimi Fan ZA1` |
| `miIo/zhimi-fan-v3` | `zhimi.fan.v3` | Smartmi Smart Wireless Fan 1st Gen (ZLBPLDS01ZM) | `Zhimi Fan V3` |
| `miIo/dmaker-fan-p5` | `dmaker.fan.p5` | Mi Smart Standing Fan 1X | `Mi Smart Standing Fan 1X` |

### miIO Plugs and Lights

| Driver folder | Device model | Product name | SmartThings driver name |
|---------------|--------------|--------------|-------------------------|
| `miIo/chuangmi-plug-m1` | `chuangmi.plug.m1` | Xiaomi Smart WiFi Socket | `Chuangmi Plug M1` |
| `miIo/chuangmi-plug-m3` | `chuangmi.plug.m3` | Xiaomi Smart WiFi Socket | `Chuangmi Plug M3` |
| `miIo/chuangmi-plug-v2` | `chuangmi.plug.v2` | Xiaomi Smart WiFi Socket | `Chuangmi Plug V2` |
| `miIo/philips-sread1` | `philips.light.sread1` | Philips Smart Desk Lamp | `Philips Smart Desk Lamp` |
| `miIo/philips-sread2` | `philips.light.sread2` | Philips Smart Desk Lamp 2 | `Philips Smart Desk Lamp 2` |
| `miIo/yeelink-light-bslamp2` | `yeelink.light.bslamp2` | Mi Bedside Lamp 2 | `Mi Bedside Lamp 2` |
| `miIo/yeelink-light-color2` | `yeelink.light.color2` | Yeelight Color Bulb V2 | `Yeelight Color Bulb V2` |
| `miIo/yeelink-light-lamp1` | `yeelink.light.lamp1` | Xiaomi Mi Desk Lamp | `Xiaomi Mi Desk Lamp` |
| `miIo/yeelink-light-mono1` | `yeelink.light.mono1` | Yeelight Mono Bulb | `Yeelight Mono Bulb` |

## Libraries

| Library | Description |
|---------|-------------|
| `libs/miot.lua` | MIoT protocol implementation (get_properties / set_properties / action) |
| `libs/miio.lua` | miIO protocol implementation (get_prop / set_prop) |
| `libs/md5.lua` | MD5 implementation used for AES key derivation - extracted from [pure_lua_SHA](https://github.com/Egor-Skriptunoff/pure_lua_SHA) (MIT) |

## Related

[smartthings-tuya-edge-driver](https://github.com/wonjj6768/smartthings-tuya-edge-driver) - SmartThings Edge Drivers for Zigbee, LAN (Tuya/Xiaomi), and Matter devices.
