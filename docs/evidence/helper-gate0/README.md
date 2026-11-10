# Production helper: Gate 0 source decision (2026-09-27)

**Result: blocked for a user-scoped component-power helper.** On the tested
MacBook Pro (Mac17,9, Apple M5 Pro, macOS 27.0), no documented, permitted
source was established for live CPU, GPU, display, SSD, or “Other” watts from
an ordinary app or user LaunchAgent. This is a source-contract finding, not a
claim that every undocumented hardware counter is inaccessible. It prevents
installing a telemetry helper or presenting component values as measured.

| Candidate | Units and coverage | Host/access result | Decision |
| --- | --- | --- | --- |
| `IOPowerSources` | Battery/UPS state; adapter rating is watts, not live draw | Already used for power-source metadata | No component watts ([Apple API](https://developer.apple.com/documentation/iokit/iopowersources_h), [adapter rating](https://developer.apple.com/documentation/iokit/kiopspoweradapterwattskey)) |
| `AppleSmartBattery.PowerTelemetryData` | Aggregate `SystemLoad`, `SystemPowerIn`, `BatteryPower` in mW in this repo's parser | Current unprivileged IORegistry sample exposed these three values only; no component keys | Keep existing system readings; no component breakdown ([parser](../../../Services/SystemPowerSourceTelemetryService.swift)) |
| `powermetrics` | Estimated CPU/GPU/ANE power on supported platforms; configurable sampling interval, default 5 s | `powermetrics -n 1 -i 1000 -s cpu_power,gpu_power,battery` exited 1: `powermetrics must be invoked as the superuser` | Incompatible with the approved user-scoped agent. The local help warns estimates may be inaccurate; disk/backlight samplers do not establish SSD/display watts ([Apple usage](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/PrioritizeWorkAtTheTaskLevel.html)) |
| MetricKit CPU/GPU/display metrics | CPU/GPU activity duration and OLED display luminance | No live hardware watt API documented | Cannot label these as component watts ([CPU](https://developer.apple.com/documentation/metrickit/mxcpumetric), [GPU](https://developer.apple.com/documentation/metrickit/mxgpumetric), [display](https://developer.apple.com/documentation/metrickit/mxdisplaymetric/averagepixelluminance)) |
| Instruments Power Profiler | Per-subsystem power-impact metrics in Apple's iPhone/iPad workflow | No documented macOS runtime component-watt API | Not a helper source ([Apple guide](https://developer.apple.com/documentation/xcode/measuring-your-app-s-power-use-with-power-profiler)) |

The direct unprivileged command above is repeatable.
`security find-identity -v -p codesigning` also returned
`0 valid identities found` on this Mac, so an
installed, Apple-signed agent could not be validated here even if Gate 0 had
passed. The repository currently has no helper executable target, launch
agent, or component sample transport; the P02 lifecycle tests use fakes.

**Decision:** stop Gates 1–4 of the approved helper plan. Do not make a root
daemon, use private counters, infer “Other” from total draw, or claim an
installed helper works under this approval. Continue the independent first
launch repair and keep Components unavailable in production. Reopen this gate
only with a documented source contract and hardware matrix: raw source,
units, cadence, timestamps, missing fields, model/OS limits, accuracy/reference
comparison, and proof that a separate process adds value. A different
privilege or estimated-power product would need a revised design decision.

The local Ralplan artifacts under `.omx/plans/` contain the conditional later
gates and their test specification.

## Independent onboarding repair

The normal AppKit startup now routes through saved onboarding progress. This
build skips the helper offer for new setup when no service is composed and
shows a Continue path for saved helper-offer, approval, or preview checkpoints.
On this Mac, a rebuilt app reopened a saved approval checkpoint with the
accessible heading “Component readings unavailable” and its Continue button;
the impossible approval spinner and System Settings instruction were absent.
The prior “This window moves on by itself” sentence was removed from the
current waiting view. Older J1.4 capture files remain historical evidence of
the prior text and are not current UI proof.

Validation on macOS 27.0: 720 package tests passed (5 skipped); native Debug
and Release builds and Xcode static analysis exited successfully. The Debug
app was launched from `.build/xcode/Build/Products/Debug/Watt.app` and inspected
through its accessibility tree. No installed agent or component sample was
claimed from those checks.
