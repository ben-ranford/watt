# Idle cost

Watt? stays running in the menu bar. This note records what the sampler schedules, what changed, and how to measure the process on a Mac.

## What was measured here

The schedule table below is from the source and from the unit tests. It is not a host measurement.

Two host samples were taken on a Mac on 18 Nov 2026 (Australia/Sydney, UTC+11). The first is commit `9072bf80`, before `main` and #56 were merged. The second is commit `95e54274`, which includes `139c9c0` (the sample also copies `AdapterDetails` and `AppleRawAdapterDetails`) and the #56 charger row. The sampler deadline is the same on both commits.

The implementation agent is Linux and did not run `top`, `powermetrics`, or `/usr/bin/time`. The figures below are the ones posted on [pull request #57](https://github.com/ben-ranford/watt/pull/57#issuecomment-6964528923) and the [follow-up](https://github.com/ben-ranford/watt/pull/57#issuecomment-6965062221).

## Schedule before and after

Read from `PowerReadingStore`, `SystemPowerSourceTelemetryService`, and `WattFallbackStatusItem` on `main` before this change. That sampler is the v1.2.0 sampler. The menu-bar deadline is the same.

| Work | Before | After |
| --- | --- | --- |
| Menu-bar sample deadline | Settings value. Default "Every 2 seconds" is 2s. "Every second" is 1s. "Every 5 seconds" is brought forward to 4.5s so it stays inside the 5s freshness window (0.5s lead). | Unchanged. |
| Sleep leeway | None. The loop used `Task.sleep` for the exact delay. | `min(10% of the deadline, 0.25s)`. The deadline does not move earlier. The latest coalesced wake for the 4.5s cap is 4.75s, leaving 0.25s of the original lead. |
| AppleSmartBattery read on each sample | `IORegistryEntryCreateCFProperties` copied the whole service entry. The parser uses `PowerTelemetryData`, and, after the adapter-name work, `AdapterDetails` and `AppleRawAdapterDetails`. | `IORegistryEntryCreateCFProperty` for those three keys. A missing key is skipped. The rest of the entry stays in the registry. |
| Helper component sample, panel hidden, menu bar not Per Component | Every 3s (`retryInterval`) once helper telemetry is attached, including while the panel is closed and the status item shows system draw, charger, battery, or the icon. | Not scheduled. The loop waits with no timer. |
| Helper component sample, panel open, or menu bar set to Per Component with component readings on | Every 3s, no leeway. | Same 3s deadline, with the leeway above. Opening the panel or selecting Per Component samples immediately instead of waiting out a leftover sleep. |
| SwiftUI panel while hidden | The production popover kept its hosting controller after close, so later samples invalidated that tree. | `popoverDidClose` drops the content view controller. The status item still updates from the menu-bar sample. |
| IOPS change notifications | Not used. | Still not used. See below. |

Fixtures do not install the component policy. With no policy, helper sampling stays on, which is the previous behaviour.

The per-key registry read later gained `Voltage`, `InstantAmperage`, and `Amperage`. A missing key is still skipped. The sampler does not copy the rest of the entry.

The stale-status task is unchanged. After a fresh system sample it sleeps until the 5s window and then invalidates the status item if nothing newer arrived. Each successful sample cancels and rearms it. It is not a second power-source poll.

`smoothReadings` is stored and shown in Settings. The sampler averages battery, charger, and system watts over the last five seconds when that switch is on. Component estimates are not part of that average.

### Why the menu bar still polls

`IOPSNotificationCreateRunLoopSource` reports power-source changes such as plug, unplug, and charge state. Charger input and battery watts still come from `AppleSmartBattery`'s `PowerTelemetryData` (`SystemPowerIn`, `BatteryPower`). That dictionary is not part of the IOPS notification, and on an M5 Pro running macOS 27.2.1 `SystemLoad` sat unchanged for about 56 seconds. On battery the menu bar uses the gas gauge instead (`Voltage` times `InstantAmperage`, or `Amperage` when instant current is missing or zero) and falls back to `SystemLoad`. AC system draw stays on `SystemLoad`, because pack current there is charge current. Replacing the poll with the IOPS notification would still leave charger and battery watts on the last value until the adapter state changed. The visible cadence stays the Settings interval.

The menu-bar sampler holds a `userInitiatedAllowingIdleSystemSleep` activity while it runs, so App Nap does not delay the next sample. That option does not disable idle system sleep.

## Regression guard

`J81NoReadingTests` drives `PowerReadingStore.runSampling` with a scripted scheduler and a frozen clock, so the assertions do not depend on wall time:

- `testSamplingToleranceStaysInsideTheFreshnessLead` bounds leeway and checks the 2s and 4.5s deadlines.
- `testHiddenPanelSchedulesOnlyTheMenuBarSample` runs five menu-bar cycles at the 2s deadline and asserts the helper sampler is never called and no other delay is scheduled.
- `testHiddenPanelStillSamplesComponentsWhenTheMenuBarShowsThem` asserts the 3s helper sleep is armed when the status item is in Per Component mode, even if the panel is hidden.
- `testOpeningThePanelSchedulesComponentSamplingAndClosingCancelsIt` asserts one helper sample when the panel opens and no further helper sleep after it closes, while menu-bar sampling continues.
- `testUnsetComponentPolicyKeepsTheHelperSampler` locks the fixture default.
- `testProductionIdlePathReleasesTheHiddenPanelAndReadsNamedRegistryKeys` checks the production call sites: the policy is installed before `startSampling()`, the popover drops its content view, and the registry read is `PowerTelemetryData`, `AdapterDetails`, `AppleRawAdapterDetails`, `Voltage`, `InstantAmperage`, and `Amperage`.

## How to measure on a Mac

Use a Release build. Quit any other Watt process. Leave the Mac plugged in, the panel closed, and the menu-bar display on System Draw (the default) unless the row you are recording says otherwise. Wait 60 seconds after the status item appears so launch work is not in the idle sample. Record the Mac model, macOS version, Watt build, power source, panel state, and display mode next to every figure.

Idle CPU and resident memory for 60 one-second samples, panel closed:

```sh
top -l 60 -s 1 -stats pid,command,cpu,mem,threads -pid "$(pgrep -x Watt)"
```

Wakeups and energy for 30 one-second samples. `powermetrics` needs an administrator:

```sh
sudo powermetrics --samplers tasks --show-process-energy --sample-rate 1000 -n 30 -i 1000
```

In that output, use the `Watt` task block. Repeat the same two commands with the panel held open.

`/usr/bin/time -l` describes the whole process, not the moment the status item appears. The status item is created on the next turns of the main run loop after `applicationDidFinishLaunching`, and the fallback waits an extra 0.5s for the menu bar to materialise. Run:

```sh
/usr/bin/time -l Watt.app/Contents/MacOS/Watt
```

Quit from the status item once it has been visible for a few seconds. Keep the real, user, and sys times and the maximum resident set size. Instruments' App Launch template is the tighter launch measurement when it is available.

### Host result, 18 Nov 2026

**Machine.** MacBook Air (Mac15,12), Apple M3, 16 GB, macOS 27.2 (26B123). Plugged in, drawing from AC. InternalBattery at 90%, not charging. Menu bar on System Draw, update interval "Every 2 seconds". Helper not installed. Load while sampling was about 2.4–3.6, and the 5-minute load was about 3.0–3.2. The Mac had been up for about 45–55 minutes. `top`'s 1-second CPU oscillates with the 2-second sample, so the averages are still noisy. An earlier session on this Mac had a load around 125; this one did not.

**Method used.** `top -l 60 -s 1 -stats pid,command,cpu,idlew,mem,threads` after a 60-second settle, panel closed and then held open. Wakeups are the `IDLEW` delta over those 60 samples. `powermetrics` was skipped because it needs an administrator. Launch is `/usr/bin/time -l` on the binary, with SIGTERM about 6 seconds after the status item appeared. `time` reports that the process terminated abnormally. The same stop was used for both builds. The Homebrew 1.2.0 process had already been running for about 30 minutes when its idle sample started. The pull-request process was a couple of minutes old, so `ps` RSS is not a like-for-like memory comparison. `top` MEM is the figure to compare.

| | Panel closed, before (Homebrew 1.2.0) | Panel closed, after (`9072bf80`) | Panel open, before (Homebrew 1.2.0) | Panel open, after (`9072bf80`) |
| --- | --- | --- | --- | --- |
| CPU % (`top`, 60s average; min–max, median) | 1.147 (0.00–3.30, median 1.00) | 0.852 (0.00–2.50, median 0.65) | 1.347 (0.00–3.40, median 1.25) | 1.190 (0.00–11.70, median 0.80) |
| Wakeups (`top` IDLEW delta over 60s) | 19 | 18 | 20 | 17 |
| Resident memory | `top` MEM 24M; `ps` RSS 64.1 MB (long-running) | `top` MEM 25–26M; `ps` RSS 94.9 MB (fresh process) | `top` MEM 32M; `ps` RSS 76.1 MB | `top` MEM 36–38M; `ps` RSS 108.1 MB |
| Launch (`/usr/bin/time -l`) | 7.09s real, 0.25s user, 0.06s sys; max RSS 93.2 MB; peak footprint 24.0 MB | 7.13s real, 0.25s user, 0.06s sys; max RSS 93.6 MB; peak footprint 24.1 MB | Same launch as the closed-panel column | Same launch as the closed-panel column |

On this run, average and median CPU were lower with the panel closed and with it open. The 11.70% open-panel maximum is one spike. Wakeups differed by a couple of counts on a 60-second window. Launch time matched. Fresh-process RSS was higher than the long-running Homebrew process on this build and on the #56 build, so that RSS gap is not evidence about this change.

**Checks on the same Mac.**

- Menu bar set to "Every 5 seconds": 60 status-item samples over about 67 seconds stayed on a live wattage (11.2 W, then 9.6 W when draw changed). The item did not show "No reading". The preference was restored afterwards.
- Opening the panel after it had been closed for 8 seconds: the 346×426 panel appeared in 514 ms with Charger input, System draw, Battery, and the Components section already visible. The helper is not installed on this Mac, so helper component estimates after a reopen were not checked.

### Follow-up on `95e54274`, same Mac

Taken 11:18–11:22 Australia/Sydney. Load was about 2.1–3.7. The Mac had been up for about 1.5 hours. This build copies `AdapterDetails` and `AppleRawAdapterDetails` on each sample and includes the #56 charger row. Launch was not measured again. The Homebrew 1.2.0 columns are the same earlier sample.

| | Panel closed, before (Homebrew 1.2.0) | Panel closed, after (`95e54274`) | Panel open, before (Homebrew 1.2.0) | Panel open, after (`95e54274`) |
| --- | --- | --- | --- | --- |
| CPU % (`top`, 60s average; min–max, median) | 1.147 (0.00–3.30, median 1.00) | 1.502 (0.00–2.80, median 1.60) | 1.347 (0.00–3.40, median 1.25) | 1.238 (0.00–15.40, median 0.75) |
| Wakeups (`top` IDLEW delta over 60s) | 19 | 30 | 20 | 16 |
| Resident memory (`top` MEM) | 24M | 25M | 32M | 38–39M |

Closed-panel average CPU and wakeups are a little higher than both Homebrew 1.2.0 and the `9072bf80` sample. Open-panel average CPU is still under Homebrew 1.2.0. The 15.40% open-panel maximum is one spike. The 1-second `top` figures are noisy, so this is not treated as a meaningful regression against 1.2.0. The closed-panel delta is the one to watch if a later sample looks worse.

On this build the panel showed **65 W charger**, matching `AdapterDetails` watts of 65. This Mac has no adapter Description or Name. Time to full and time to empty stayed hidden, which is correct while the battery is not charging (`IOPS` time to full and time to empty were 0, and `TimeRemaining` in the registry was 65535). Charger input, System draw, Battery, and the Components section (Helper not installed) appeared with the panel. The "Every 5 seconds" check was on `9072bf80`. The menu-bar deadline did not change in `139c9c0`.

### What these Mac runs did not cover

- `powermetrics` wakeups and energy. The wakeup rows are `top` IDLEW.
- Per Component in the menu bar while the panel is closed.
- A helper sample appearing after the panel is reopened. This Mac has no helper.
