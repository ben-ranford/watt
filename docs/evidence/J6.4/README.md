# G053 / J6.4 — Charger can’t keep up

Exact source: [Figma node 31:4956](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-4956).
The exact supplied PNG is retained as `reference.png` (1000 × 720 pixels), SHA-256
`7256ff7ac281ea2e2f26a22b6a70ccee4f874a6c72f3a70b222202328d54881b`.
The inspected dark native panel is approximately x645/y38, 320 × 279 points.
The reference panel ends its explanation after “65 W.”; the notification includes
the final sentence. The user's explicit full panel/notification message takes precedence.

## Native mapping

The existing StatusPanelModel/StatusPanelView supplies the semantic insufficient-charger
state with a native warning SF Symbol and grouped Form/Section/LabeledContent rows.
Eligibility requires explicit validated charger-threshold provenance (episode identity,
observation timestamp and at least 300 seconds sustained), fresh available finite
battery/charger/system telemetry and the store's five-second age gate. Negative battery
watts or adapter presence alone cannot establish the warning. No production threshold
inference or synthetic provenance is introduced.

Exact content:

- Charger can’t keep up; −13.0 W.
- Because your Mac draws 78 W and this charger gives 65 W. The battery covers the rest.
- Charger input / 67 W USB-C charger / 65.0 W.
- System draw / 78.0 W.
- Battery / −13.0 W.
- Settings… and Quit Watt?.

Components are hidden. Existing borderless native footer callbacks remain intact.
The selected NSStatusItem shows the battery glyph and −13.0 W; MenuBarExtra owns the
native panel material, shape and shadow. No custom window/chrome/background is added.

## System notification boundary

The OS owns the notification, its AppIcon and compositor presentation. Existing P03
PowerNotificationEffects/SystemNotificationBridge contracts carry semantic title and
message requests. Deterministic fixture scenarios exercise preference × authorization
eligibility and intent only. The recording driver throws `unknownStatus` rather than
claiming enqueue acceptance or delivery. No notification card or Notification Center
is drawn or captured, and permission is never requested or changed.

Five DEBUG selectors are supported: `J6.4/base`, `J6.4/notification-on-authorized`,
`J6.4/notification-on-denied`, `J6.4/notification-off-authorized`, and
`J6.4/notification-off-denied`. Each uses isolated memory preferences/store and the
same fresh −13/65/78 W sample with a 67 W adapter, dark Aqua, completed onboarding,
Components off and the native panel route. Release excludes the fixture harness.
Malformed and unsupported selectors reject before composition.

Capture adds `--watt-j64-probe-notification-authorization` to read actual system
notification authorization without changing it. Its app log distinguishes actual
permission from deterministic fixture intent. Live adapter threshold provenance is
unavailable in this fixture, so real OS delivery cannot be established or claimed.
Even authorized status or accepted enqueue alone would not prove visible OS delivery.

## Reproduction

```sh
bash docs/evidence/J6.4/verify.sh
bash docs/evidence/J6.4/capture.sh
```

`verify.sh` runs focused/full package tests, package build, native Debug/Release
build + analyze, focused/full native host tests, five actual invalid-selector launches,
diff and static checks. Each command writes its own log and exit code. Static checks
include script/JSON syntax, capture Swift typecheck, exact reference digest, native
view contracts and Debug/Release symbol isolation. Native tests do not prove pixels.

`capture.sh` requires a fresh capture directory, launches only the J6.4 Debug fixture,
and terminates/reaps that PID. Capture requires preauthorized Screen Recording and
Accessibility trust, unique exact live AX panel content, and a matching PID-owned
compositor window. Ownership is rechecked before/after capture. It never substitutes
a cached view, custom window, desktop image or synthetic screenshot. Notification
Center and system notification windows are explicitly outside its capture boundary.

## Evidence status

Verification passed: focused package/native suites each ran 134 tests (3 AX skips),
full package ran 476 tests and full native ran 464 tests (4 AX skips each), all with
zero failures. J6.4 contributes 15 tests (1 AX skip). Debug/Release build + analyze,
Release symbol exclusion, static/diff checks and all five actual invalid-selector
launches passed. The pre-existing onboarding actor-isolation warning remains.

Real capture exited 1: Screen Recording was preauthorized, Accessibility trust was
unavailable and no Watt-owned compositor window was enumerated. The fixture PID was
terminated and reaped. `capture/app.log` was empty, so the read-only native notification
authorization probe produced no evidence. No live permission, enqueue acceptance or
system delivery is claimed. No system notification was captured and no permission
was requested or changed. Visual acceptance is blocked; score and pixel diff are null.

See `verification.json`, `visual-review.json`, `notification-evidence.json`,
`capture/window.json`, command logs and `changed-files.json` for scoped details.
Native host callback/highlight tests pass, but live keyboard/navigation, dismissal,
VoiceOver and selected status-item pixels remain unverified.

No commit is requested. Cumulative worktree changes must remain preserved.
