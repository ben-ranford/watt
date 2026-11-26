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
    <img src="docs/screenshots/panel-light.png" width="360" alt="The panel, with charger input, system draw, and battery power.">
  </picture>
</p>

Watt lives in your menu bar and shows where your Mac's power is going: what the charger is supplying, what the Mac is drawing, and whether the battery is filling or emptying. It's free and open source, and it never touches your charging.

## Install

Requires macOS 13 or later.

### Homebrew

```sh
brew install --cask ben-ranford/tap/watt
```

The cask comes from [ben-ranford/homebrew-tap](https://github.com/ben-ranford/homebrew-tap).

### Download

Or grab the latest `.dmg` from [Releases](https://github.com/ben-ranford/watt/releases/latest) and drag Watt into Applications.

## Features

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/menu-bar-dark.png">
    <img src="docs/screenshots/menu-bar-light.png" width="224" alt="Menu bar item showing system draw.">
  </picture>
</p>

- Live system draw in the menu bar, or switch to battery, charger, CPU/GPU, or just the icon
- Optional battery percentage in the menu bar, next to the watts or on its own, and a battery icon that follows the charge
- See which charger is plugged in and its rated wattage
- Time to full, or time left on battery
- Optional alerts when your charger can't keep up, the battery's full, or it's running low
- Light and dark mode, launch at login, adjustable refresh rate

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/settings-dark.png">
    <img src="docs/screenshots/settings-light.png" width="480" alt="Settings window">
  </picture>
</p>

Charging feeling slow? [Here's how to tell why](https://ben-ranford.github.io/watt/why-is-my-mac-charging-slowly.html). Wondering how Watt stacks up against Stats, AlDente and iStat Menus? [See the comparison](https://ben-ranford.github.io/watt/compare.html).

## FAQ

### Does it limit charging?

No. Watt just shows the numbers. If you want to cap your charge, use AlDente or the Charge Limit option in Battery settings.

### Can I use it from Shortcuts?

Yes. Shortcuts can read the current sample, open the panel or Settings, and change the menu-bar display. The manual check is [docs/shortcuts.md](docs/shortcuts.md).

### Why does it ask for a helper?

Only for CPU and GPU readings. Everything else works without it. If you want those, setup asks for your password once and macOS asks you to allow it in Login Items. You can skip it, or remove it later in Settings.

### Does it send my readings anywhere?

No. Everything stays on your Mac and there's no analytics. The only network request is the update check, which you can turn off in Settings.

## Support

Found a bug or have an idea? [Open an issue](https://github.com/ben-ranford/watt/issues). If you'd like to chip in, [GitHub Sponsors](https://github.com/sponsors/ben-ranford) is appreciated but never expected.

Want to build it yourself? See [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence

[MIT](LICENSE) © 2026 Benjamin Ranford
