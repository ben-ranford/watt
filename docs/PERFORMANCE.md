# Idle cost

Watt? stays running in the menu bar. This note records what the sampler schedules, what changed, and how to measure the process on a Mac.

## What was measured here

No host numbers were collected for this change.

The edit was made on a Linux agent. `uname` reported Linux, and `swift`, `xcodebuild`, Instruments, and `powermetrics` were not installed. Watt is a macOS app, so those tools could not have produced a CPU, wakeup, memory, or launch-time figure here. The schedule table is taken from the source and from the unit tests named below. It is not a substitute for the host procedure.

## Schedule before and after

Read from `PowerReadingStore`, `SystemPowerSourceTelemetryService`, and `WattFallbackStatusItem` on `main` before this change. That sampler is the v1.2.0 sampler. The menu-bar deadline is the same.

| Work | Before | After |
| --- | --- | --- |
| Menu-bar sample deadline | Settings value. Default "Every 2 seconds" is 2s. "Every second" is 1s. "Every 5 seconds" is brought forward to 4.5s so it stays inside the 5s freshness window (0.5s lead). | Unchanged. |
| Sleep leeway | None. The loop used `Task.sleep` for the exact delay. | `min(10% of the deadline, 0.25s)`. The deadline does not move earlier. The latest coalesced wake for the 4.5s cap is 4.75s, leaving 0.25s of the original lead. |
| AppleSmartBattery read on each sample | `IORegistryEntryCreateCFProperties` copied the whole service entry. The parser uses only `PowerTelemetryData`. | `IORegistryEntryCreateCFProperty` for `PowerTelemetryData` only. A missing property still produces a metadata-only reading. |
| Helper component sample, panel hidden, menu bar not Per Component | Every 3s (`retryInterval`) once helper telemetry is attached, including while the panel is closed and the status item shows system draw, charger, battery, or the icon. | Not scheduled. The loop waits with no timer. |
| Helper component sample, panel open, or menu bar set to Per Component with component readings on | Every 3s, no leeway. | Same 3s deadline, with the leeway above. Opening the panel or selecting Per Component samples immediately instead of waiting out a leftover sleep. |
| SwiftUI panel while hidden | The production popover kept its hosting controller after close, so later samples invalidated that tree. | `popoverDidClose` drops the content view controller. The status item still updates from the menu-bar sample. |
| IOPS change notifications | Not used. | Still not used. See below. |

Fixtures do not install the component policy. With no policy, helper sampling stays on, which is the previous behaviour.

The stale-status task is unchanged. After a fresh system sample it sleeps until the 5s window and then invalidates the status item if nothing newer arrived. Each successful sample cancels and rearms it. It is not a second power-source poll.

`smoothReadings` is stored and shown in Settings. The sampler does not read it, so this change does not touch that control.

### Why the menu bar still polls

`IOPSNotificationCreateRunLoopSource` reports power-source changes such as plug, unplug, and charge state. The watts in the status item come from `AppleSmartBattery`'s `PowerTelemetryData` (`SystemLoad`, `SystemPowerIn`, `BatteryPower`). That dictionary is not part of the IOPS notification. Replacing the poll with the notification would leave the status item on the last wattage until the adapter state changed. The visible cadence stays the Settings interval.

## Regression guard

`J81NoReadingTests` drives `PowerReadingStore.runSampling` with a scripted scheduler and a frozen clock, so the assertions do not depend on wall time:

- `testSamplingToleranceStaysInsideTheFreshnessLead` bounds leeway and checks the 2s and 4.5s deadlines.
- `testHiddenPanelSchedulesOnlyTheMenuBarSample` runs five menu-bar cycles at the 2s deadline and asserts the helper sampler is never called and no other delay is scheduled.
- `testHiddenPanelStillSamplesComponentsWhenTheMenuBarShowsThem` asserts the 3s helper sleep is armed when the status item is in Per Component mode, even if the panel is hidden.
- `testOpeningThePanelSchedulesComponentSamplingAndClosingCancelsIt` asserts one helper sample when the panel opens and no further helper sleep after it closes, while menu-bar sampling continues.
- `testUnsetComponentPolicyKeepsTheHelperSampler` locks the fixture default.
- `testProductionIdlePathReleasesTheHiddenPanelAndReadsOneRegistryProperty` checks the production call sites: the policy is installed before `startSampling()`, the popover drops its content view, and the registry read is the single `PowerTelemetryData` property.

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

Fill the host table from those commands. Do not copy the schedule numbers above into it.

| | Panel closed, before | Panel closed, after | Panel open, before | Panel open, after |
| --- | --- | --- | --- | --- |
| CPU % (`top`) | | | | |
| Wakeups (`powermetrics`) | | | | |
| Resident memory | | | | |
| Launch (`/usr/bin/time -l` or Instruments) | | | | |

### What still needs a Mac

- The host table above.
- Status item on "Every 5 seconds" does not flip to "No reading" during a quiet minute. The coalesced wake can land as late as 4.75s, and the reading expires at 5s.
- Per Component in the menu bar still updates while the panel is closed.
- With the helper installed, opening the panel after it has been closed shows component rows after one helper sample. Until that sample returns, the panel uses the same empty component state it already uses when no fresh estimate exists.
