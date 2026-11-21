<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Watt?">
</p>

<h1 align="center">Watt?</h1>

<p align="center">Native macOS menu-bar app that shows live charger, system and battery power in watts.</p>

<p align="center">
  <a href="https://github.com/ben-ranford/watt/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/ben-ranford/watt?style=flat-square"></a>
  <a href="https://github.com/ben-ranford/watt/releases"><img alt="GitHub downloads" src="https://img.shields.io/github/downloads/ben-ranford/watt/total?style=flat-square"></a>
  <img alt="Requires macOS 13 or later" src="https://img.shields.io/badge/macOS-13%2B-black?style=flat-square">
  <a href="LICENSE"><img alt="MIT licence" src="https://img.shields.io/badge/licence-MIT-blue?style=flat-square"></a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/panel-dark.png">
    <img src="docs/screenshots/panel-light.png" width="360" alt="The Watt? panel, with charger input, system draw, and battery power.">
  </picture>
</p>

Watt? sits in the menu bar and answers one question: where are the watts going? Click the item for charger input, what the Mac is using, and whether the battery is filling or emptying.

It is free. It does not limit charging.

## Why Watt?

- One job, not a system monitor. Charger, system, and battery, in watts.
- Free, with the source published under the MIT licence.
- It does not hold the battery at a percentage, and it has no paid tier.

[How it compares](#how-it-compares) with Stats, AlDente, coconutBattery, and iStat Menus.

## Install

Watt? needs macOS 13 or later.

### Homebrew

```sh
brew install --cask ben-ranford/tap/watt
```

The cask is published from [ben-ranford/homebrew-tap](https://github.com/ben-ranford/homebrew-tap). It installs the app. The optional helper is a choice inside Watt?, not part of the install.

Watt? updates itself. `brew upgrade` leaves it alone unless you pass `--greedy`.

### Download

Download the zip or the disk image from [GitHub Releases](https://github.com/ben-ranford/watt/releases/latest), move Watt into Applications, and open it.

**Check for Updates…** is in the menu-bar menu. **Check for Updates Now** is in Settings. Automatic checks start on, and Settings can turn them off. The first launch after an update shows **What’s New** once.

## Features

Click the menu-bar item for the panel. Watt? has no Dock icon. The menu on that item chooses the reading, opens Settings, checks for updates, and quits.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/menu-bar-dark.png">
    <img src="docs/screenshots/menu-bar-light.png" width="224" alt="Menu bar item showing system draw.">
  </picture>
</p>

The menu bar can show:

- **System draw**, the reading a new install uses. This is the useful number when the Mac is plugged in and holding its charge.
- **Battery**, how fast the battery is filling or emptying.
- **Charger**, what the adapter is supplying.
- **CPU and GPU**, after the helper is allowed and both numbers are available.
- **Icon only**, for a crowded menu bar.

The panel names the adapter and its rated wattage when the Mac reports them. Time to full, or time left on battery, appears only when macOS has a real estimate. An idle battery while the Mac is plugged in, including a charge macOS is holding, shows 0.0 W and the title **Not charging**.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/settings-dark.png">
    <img src="docs/screenshots/settings-light.png" width="480" alt="Watt? Settings.">
  </picture>
</p>

Settings can set:

- The reading, and whether a symbol is shown beside it.
- Precision: whole watts, or one or two decimal places.
- How often the reading updates: every second, every 2 seconds, or every 5 seconds.
- Smooth readings, which average the last 5 seconds.
- Notifications when the charger cannot keep up (5 minutes by default), when the battery is full (100% by default), and for a low battery (20% by default, off until you turn it on).
- Open at login. This stays off until you turn it on, in setup or in Settings.

CPU and GPU are the only component readings. Display, SSD, and Other are not included. The menu bar shows at most two of them.

If charging looks slow, [Why is my Mac charging slowly?](https://ben-ranford.github.io/watt/why-is-my-mac-charging-slowly.html) reads the same three rows.

## How it compares

Watt? is the smaller app when you only want the watts. “Lighter than Stats” means a narrower app, not a measured difference in CPU or memory. Nothing here is a benchmark. Where an app charges, the price is on that app’s site.

| | Price | Open source | Focus | Limits charging |
| --- | --- | --- | --- | --- |
| **Watt?** | Free | Yes, MIT | Where the watts are going | No |
| [Stats](https://github.com/exelban/stats) | Free | Yes, MIT | Menu-bar monitor for the whole Mac | No |
| [AlDente](https://apphousekitchen.com/aldente-overview/) | Free version. [Pro is paid](https://apphousekitchen.com/aldente-overview/pricing/) | No. The current app is not | Holding the charge at a percentage | Yes |
| [coconutBattery](https://www.coconut-flavour.com/coconutbattery/) | Free edition. Plus is a one-time purchase | — | Battery health, including iPhone and iPad | No |
| [iStat Menus](https://bjango.com/mac/istatmenus/) | [Paid](https://bjango.com/mac/istatmenus/) | — | Menu-bar system monitor | No |

A dash is something this page does not claim. The longer notes are on [the compare page](https://ben-ranford.github.io/watt/compare.html).

- Use Watt? for charger, system, and battery watts, with no charge limit.
- Use Stats or iStat Menus for a system monitor. Stats is free and open source. iStat Menus is paid.
- Use AlDente, or Charge Limit in macOS Battery settings, to stop the battery at a percentage. On Apple silicon with macOS Tahoe 26.4 or later, that setting runs from 80 to 100 percent. Watt? does not do this.
- Use coconutBattery for battery health. Watt? does not show a cycle count, a design capacity, or a health percentage, and it does not read an iPhone or an iPad.

## Privacy

Watt? does not collect usage data, and it has no analytics.

Charger, system, and battery readings stay on your Mac. The helper, if you allow it, reads CPU and GPU power and does not use the network. It sends nothing off the Mac.

The only network use is updates. If checks are left on, Watt? downloads an update notice from this project’s site, and the update itself if you accept it. It does not upload your readings. Settings can turn automatic checks off.

## FAQ

### Does Watt? limit charging?

No. It shows the watts. It does not hold the battery at a percentage, and it does not change how macOS charges.

### Why does it need a helper?

Charger, system, and battery watts do not need it. CPU and GPU watts do. Setup asks for your password once, then macOS asks you to allow **Watt? Helper** in Login Items & Extensions. You can skip it. Homebrew does not install it for you.

### What does the helper do?

It reads CPU and GPU power so those two numbers can appear. It does not change charging. Display, SSD, and Other stay unavailable. You can remove it in Settings.

### Which Macs?

macOS 13 or later. On a laptop, charger, system, and battery watts show up when the Mac reports them. A desktop has no battery, so Watt? shows what the Mac is drawing.

## Support

Watt? is free. [GitHub Sponsors](https://github.com/sponsors/ben-ranford) is there for anyone who wants to support development.

Questions and bug reports go in [GitHub issues](https://github.com/ben-ranford/watt/issues).

## Licence

[MIT](LICENSE) © 2026 Benjamin Ranford

## Build from source

[Build from source / Contributing](CONTRIBUTING.md)
