# Changelog

## [1.3.1](https://github.com/ben-ranford/watt/compare/v1.4.0...v1.3.1) (2026-11-26)


### Features

* add low-battery alerts and configurable notification thresholds ([#48](https://github.com/ben-ranford/watt/issues/48)) ([7bc3add](https://github.com/ben-ranford/watt/commit/7bc3add0b9fb6aa04e5fd52f7c548fefcfac7af9))
* **helper:** decode powermetrics samples into component readings ([#73](https://github.com/ben-ranford/watt/issues/73)) ([c085392](https://github.com/ben-ranford/watt/commit/c0853929233f32aa0264631b0f59f965e6d906c8))
* initial public release of Watt ([6f7df28](https://github.com/ben-ranford/watt/commit/6f7df28df9f678cf24875eb076b45c1d1b4c69f2))
* **menu-bar:** add optional battery percentage and icon ([#79](https://github.com/ben-ranford/watt/issues/79)) ([25667eb](https://github.com/ben-ranford/watt/commit/25667eb0f22c342c401441595222547bf001ea43))
* **onboarding:** strike Done with lightning when setup finishes ([#87](https://github.com/ben-ranford/watt/issues/87)) ([f6dd6a8](https://github.com/ben-ranford/watt/commit/f6dd6a8cd456779469ae400d7958a81414473f47))
* show adapter wattage and time remaining in the panel ([#56](https://github.com/ben-ranford/watt/issues/56)) ([01a3681](https://github.com/ben-ranford/watt/commit/01a36818e320fbb0a90049e26e3bf518c31bca60))
* show release notes in the update prompt ([#40](https://github.com/ben-ranford/watt/issues/40)) ([0c0036e](https://github.com/ben-ranford/watt/commit/0c0036e66a3fbc4cc8ead9d2c509e904fc2ca947))
* stage update rollouts and show what changed once ([#54](https://github.com/ben-ranford/watt/issues/54)) ([9149256](https://github.com/ben-ranford/watt/commit/91492565926b0ebbbd18061cb81b6490eb9a1253))
* subtle UI motion ([#53](https://github.com/ben-ranford/watt/issues/53)) ([b25e899](https://github.com/ben-ranford/watt/commit/b25e89979dec45439f685f42f51530ddb942fe1d))


### Bug Fixes

* **build:** compile the width and battery tests into WattTests again ([#95](https://github.com/ben-ranford/watt/issues/95)) ([8c0f55c](https://github.com/ben-ranford/watt/commit/8c0f55ccb1677c482ab7fafeec140e9c036ff055))
* compile update endpoints into the release Info.plist ([#30](https://github.com/ben-ranford/watt/issues/30)) ([210ff87](https://github.com/ben-ranford/watt/commit/210ff876405405000b9ae320e3a4296b799bb135))
* **copy:** remove em dashes from user-facing text ([#85](https://github.com/ben-ranford/watt/issues/85)) ([5064962](https://github.com/ben-ranford/watt/commit/506496251d173bc85a16481424412e710cde7766))
* don't block launch when the app is in Downloads ([#51](https://github.com/ben-ranford/watt/issues/51)) ([275a497](https://github.com/ben-ranford/watt/commit/275a4979eec8389157558cbb0c716fd92c95b4f2))
* first-run polish from fresh-install test ([#42](https://github.com/ben-ranford/watt/issues/42)) ([364379f](https://github.com/ben-ranford/watt/commit/364379fd86141c882f7744c253aee589932a401c))
* **helper:** finish helper install on a Mac that never had it ([#86](https://github.com/ben-ranford/watt/issues/86)) ([fed24d3](https://github.com/ben-ranford/watt/commit/fed24d3e8fc52570abe8561bd0acffd466509fed))
* **helper:** route updates and helper removal through the protected copy ([#84](https://github.com/ben-ranford/watt/issues/84)) ([f8e9899](https://github.com/ben-ranford/watt/commit/f8e9899d72c39bf5a07555e578f9ec6991bd255a))
* **menubar:** keep status item width stable as readings change ([#75](https://github.com/ben-ranford/watt/issues/75)) ([5787a96](https://github.com/ben-ranford/watt/commit/5787a96cb043d3d1e26418d9b8f2e0b7eaa330d9))
* modern Homebrew cask and version-agnostic live manifest test ([#44](https://github.com/ben-ranford/watt/issues/44)) ([cddf121](https://github.com/ben-ranford/watt/commit/cddf121e97ea5d099fb22b54b4759c9f81cb329b))
* **onboarding:** install helper before choosing components ([#70](https://github.com/ben-ranford/watt/issues/70)) ([b32e769](https://github.com/ben-ranford/watt/commit/b32e769eb4de44334c446d0a935c237b69242d6d))
* **onboarding:** plain the first-run copy ([#69](https://github.com/ben-ranford/watt/issues/69)) ([e9c776c](https://github.com/ben-ranford/watt/commit/e9c776c8bc7e3a03d08dc9d994406f89410f8449))
* quit the previous Watt after a successful update handoff ([#46](https://github.com/ben-ranford/watt/issues/46)) ([73fc96e](https://github.com/ben-ranford/watt/commit/73fc96e7d864549a24f0de7a25aa855a49ac2066))
* **release:** read signing authority with codesign -dvv ([#81](https://github.com/ben-ranford/watt/issues/81)) ([205b508](https://github.com/ben-ranford/watt/commit/205b508f7f6f8b8be1fe38b3e840eccefc98fad9))
* render release note headings and bullets on separate lines ([#59](https://github.com/ben-ranford/watt/issues/59)) ([0573c4d](https://github.com/ben-ranford/watt/commit/0573c4d7bea6ac5302d1004571b23906f5bf3208))
* ship the real app icon in place of placeholder art ([#41](https://github.com/ben-ranford/watt/issues/41)) ([c9ad867](https://github.com/ben-ranford/watt/commit/c9ad8676a3b96429610f2b3c833896958ca6b782))
* **telemetry:** read signed BatteryPower so panel shows on battery ([#71](https://github.com/ben-ranford/watt/issues/71)) ([bfc15cc](https://github.com/ben-ranford/watt/commit/bfc15ccb831f830d1852cebb369b7a969b4dc9e8))
* **updates:** finish a check when the manifest request completes ([#67](https://github.com/ben-ranford/watt/issues/67)) ([440b392](https://github.com/ben-ranford/watt/commit/440b392f7016d102b6cfe3b954635e68078f3c2d))


### Performance Improvements

* cut idle sampling while the menu bar keeps its cadence ([#57](https://github.com/ben-ranford/watt/issues/57)) ([8f89387](https://github.com/ben-ranford/watt/commit/8f89387b38468f716e4f6bef6a23e53f4cdc279c))

## [1.4.0](https://github.com/ben-ranford/watt/compare/v1.3.2...v1.4.0) (2026-11-26)


### Features

* The menu bar can show your battery percentage, after the watts or on its own, and can use a battery icon instead of the bolt. Both are off until you turn them on in Settings, and only appear on a Mac with a battery. (#79)
* Finishing setup ends with a lightning strike on Done. (#87)


### Bug Fixes

* The menu bar item keeps the same width as the reading changes, so the items next to it stay put. (#75)
* Settings and the website use plainer punctuation. (#85)
* More of the app's own checks run on every build. (#95)

## [1.3.2](https://github.com/ben-ranford/watt/compare/v1.3.1...v1.3.2) (2026-11-26)


### Bug Fixes

* Install Helper finishes after you enter your password, including on a Mac that never had the helper, and it finishes an install that stopped part way. (#86)
* Installing the helper never waits forever. If it takes too long or is cancelled, Watt? says so and you can try again. (#86)
* Settings and the menu bar panel show the helper's real state, such as "Not finished" or "Other copy", instead of always "Not installed". (#86)
* The menu bar keeps showing a reading when a busy Mac uses more power than the charger gives. (#86)
* The helper screen explains what the helper is for. (#86)
* Remove Helper works, and Check for Updates works in the copy of Watt? that the helper keeps safe. (#84)

## [1.3.1](https://github.com/ben-ranford/watt/compare/v1.2.0...v1.3.1) (2026-11-25)

1.3.1 is the first published release with the 1.3.0 changes. It also fixes the release check that stopped 1.3.0 from being published.

### Features

* See CPU and GPU power separately. With the helper on, the panel shows a CPU estimate and a GPU estimate. (#73)
* The panel shows your charger's wattage and how long until the battery is full or empty. (#56)
* Updates roll out gradually, and Watt? shows what changed once after it updates. (#54)
* Subtle motion in the panel and windows. (#53)

### Bug Fixes

* Plainer wording on every first-run screen. (#69)
* First run offers the helper before you pick what the menu bar shows, so CPU and GPU are ready to choose. (#70)
* Checking for updates no longer gets stuck on "Checking…". If Watt? can't connect, it says so. (#67)
* System draw and battery readings now show in the panel while your Mac runs on battery. (#71)
* Release notes in the update window show headings and bullets on separate lines. (#59)
* Fixed the release check that stopped 1.3.0 from being published. (#81)

### Performance Improvements

* Uses less energy at idle while the menu bar keeps updating on time. (#57)

## [1.3.0](https://github.com/ben-ranford/watt/compare/v1.2.0...v1.3.0) (2026-11-25)

Not published. Superseded by 1.3.1, which ships these changes.


### Features

* **helper:** decode powermetrics samples into component readings ([#73](https://github.com/ben-ranford/watt/issues/73)) ([c085392](https://github.com/ben-ranford/watt/commit/c0853929233f32aa0264631b0f59f965e6d906c8))
* show adapter wattage and time remaining in the panel ([#56](https://github.com/ben-ranford/watt/issues/56)) ([01a3681](https://github.com/ben-ranford/watt/commit/01a36818e320fbb0a90049e26e3bf518c31bca60))
* stage update rollouts and show what changed once ([#54](https://github.com/ben-ranford/watt/issues/54)) ([9149256](https://github.com/ben-ranford/watt/commit/91492565926b0ebbbd18061cb81b6490eb9a1253))
* subtle UI motion ([#53](https://github.com/ben-ranford/watt/issues/53)) ([b25e899](https://github.com/ben-ranford/watt/commit/b25e89979dec45439f685f42f51530ddb942fe1d))


### Bug Fixes

* **onboarding:** install helper before choosing components ([#70](https://github.com/ben-ranford/watt/issues/70)) ([b32e769](https://github.com/ben-ranford/watt/commit/b32e769eb4de44334c446d0a935c237b69242d6d))
* **onboarding:** plain the first-run copy ([#69](https://github.com/ben-ranford/watt/issues/69)) ([e9c776c](https://github.com/ben-ranford/watt/commit/e9c776c8bc7e3a03d08dc9d994406f89410f8449))
* render release note headings and bullets on separate lines ([#59](https://github.com/ben-ranford/watt/issues/59)) ([0573c4d](https://github.com/ben-ranford/watt/commit/0573c4d7bea6ac5302d1004571b23906f5bf3208))
* **telemetry:** read signed BatteryPower so panel shows on battery ([#71](https://github.com/ben-ranford/watt/issues/71)) ([bfc15cc](https://github.com/ben-ranford/watt/commit/bfc15ccb831f830d1852cebb369b7a969b4dc9e8))
* **updates:** finish a check when the manifest request completes ([#67](https://github.com/ben-ranford/watt/issues/67)) ([440b392](https://github.com/ben-ranford/watt/commit/440b392f7016d102b6cfe3b954635e68078f3c2d))


### Performance Improvements

* cut idle sampling while the menu bar keeps its cadence ([#57](https://github.com/ben-ranford/watt/issues/57)) ([8f89387](https://github.com/ben-ranford/watt/commit/8f89387b38468f716e4f6bef6a23e53f4cdc279c))

## [1.2.0](https://github.com/ben-ranford/watt/compare/v1.1.1...v1.2.0) (2026-11-11)


### Features

* add low-battery alerts and configurable notification thresholds ([#48](https://github.com/ben-ranford/watt/issues/48)) ([7bc3add](https://github.com/ben-ranford/watt/commit/7bc3add0b9fb6aa04e5fd52f7c548fefcfac7af9))


### Bug Fixes

* don't block launch when the app is in Downloads ([#51](https://github.com/ben-ranford/watt/issues/51)) ([275a497](https://github.com/ben-ranford/watt/commit/275a4979eec8389157558cbb0c716fd92c95b4f2))

## [1.1.1](https://github.com/ben-ranford/watt/compare/v1.1.0...v1.1.1) (2026-11-11)


### Bug Fixes

* modern Homebrew cask and version-agnostic live manifest test ([#44](https://github.com/ben-ranford/watt/issues/44)) ([cddf121](https://github.com/ben-ranford/watt/commit/cddf121e97ea5d099fb22b54b4759c9f81cb329b))
* quit the previous Watt after a successful update handoff ([#46](https://github.com/ben-ranford/watt/issues/46)) ([73fc96e](https://github.com/ben-ranford/watt/commit/73fc96e7d864549a24f0de7a25aa855a49ac2066))

## [1.1.0](https://github.com/ben-ranford/watt/compare/v1.0.1...v1.1.0) (2026-11-11)


### Features

* show release notes in the update prompt ([#40](https://github.com/ben-ranford/watt/issues/40)) ([0c0036e](https://github.com/ben-ranford/watt/commit/0c0036e66a3fbc4cc8ead9d2c509e904fc2ca947))


### Bug Fixes

* first-run polish from fresh-install test ([#42](https://github.com/ben-ranford/watt/issues/42)) ([364379f](https://github.com/ben-ranford/watt/commit/364379fd86141c882f7744c253aee589932a401c))
* ship the real app icon in place of placeholder art ([#41](https://github.com/ben-ranford/watt/issues/41)) ([c9ad867](https://github.com/ben-ranford/watt/commit/c9ad8676a3b96429610f2b3c833896958ca6b782))

## [1.0.1](https://github.com/ben-ranford/watt/compare/v1.0.0...v1.0.1) (2026-11-10)


### Bug Fixes

* compile update endpoints into the release Info.plist ([#30](https://github.com/ben-ranford/watt/issues/30)) ([210ff87](https://github.com/ben-ranford/watt/commit/210ff876405405000b9ae320e3a4296b799bb135))

## [1.0.0](https://github.com/ben-ranford/watt/compare/v1.0.0...v1.0.0) (2026-11-10)


### Features

* initial public release of Watt ([6f7df28](https://github.com/ben-ranford/watt/commit/6f7df28df9f678cf24875eb076b45c1d1b4c69f2))

## Changelog
