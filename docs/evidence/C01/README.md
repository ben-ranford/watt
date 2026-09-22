# C01 — Charging panel (21:928)

Implementation complete; **independent visual-ralph verdict: 92/100 PASS**.
The C01 visual correction is closed with residual material/typography differences;
AX/VoiceOver, live interaction and production telemetry remain separate gaps.
Only C01 is renderable from the F05 native Debug gate. `C01` and `C01/base`
select fixed `.sampleCharging`, its pinned clock, and a fresh `InMemoryStorage`
before ordinary app composition. Package executable fixture launches still reject;
Release compiles neither registry nor fixture/capture paths.

## Reproduce (repository root)

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/c01-native build
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/c01-native \
  test -only-testing:WattTests -parallel-testing-enabled NO
swift test --scratch-path .build/c01-package
bash docs/evidence/C01/capture.sh
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release \
  -destination 'platform=macOS' -derivedDataPath .build/c01-release build analyze
```

`capture.swift` is a C01-local variant of the existing window-only capture helper,
kept here to avoid changes to shared F05 tooling. It preflights existing Screen
Recording access, selects exactly the app PID/title, and uses `screencapture -l`.
It never requests permission, captures the desktop, synthesizes AX input, or
modifies TCC. It renders the real app-owned panel view, not a drawn screenshot.
The capture window calls the app router for Settings; Quit terminates normally.
The system-owned selected status-item background is **not** inside this panel crop.

## Artifacts and scale

- `reference-21-928.png`: exact retained 900×640 Figma export (unaltered).
- `reference-panel.png`: source-pixel crop x551 y40 width320 height473, with JSON.
- `gallery-C01.png`: original native dark 640×946 screenshot (2 pixels/point).
- `window.json`: PID/window bounds, appearance, scale and capture metadata.
- `captured-panel-1x.png`: explicitly normalized 320×473 derivative using
  `sips -z 473 320`; **not** a raw 1x capture. Raw evidence is retained above.
- `comparison.json`, `comparison-diff.png`, `comparison-overlay.png`: same-scale
  1px/point comparison, no masks. Deterministic native tint and Figma colors
  still differ; the strict 1% pixel tolerance fails. This is diagnostic,
  not a visual acceptance metric. No claim of a native-unresampled pixel match.
- `visual-review.json`: independent verdict, outstanding gaps and preserved provenance.

Comparison reproduction:
```sh
xcrun swiftc scripts/F05/image-evidence.swift -o .build/c01-image-evidence
.build/c01-image-evidence crop docs/evidence/C01/reference-21-928.png \
  docs/evidence/C01/reference-panel.png 551 40 320 473
sips -z 473 320 docs/evidence/C01/gallery-C01.png \
  --out docs/evidence/C01/captured-panel-1x.png
.build/c01-image-evidence diff docs/evidence/C01/reference-panel.png \
  docs/evidence/C01/captured-panel-1x.png docs/evidence/C01/comparison 1 1 0.01
# Expected exit 2: pixel tolerance fails; keep JSON for the visual verifier.
```

## Coverage and remaining gaps

Unit tests cover exact values, capabilities (unsupported, permission-required,
disconnected, unknown), unavailable source/freshness, formatter signs/zero/nonfinite,
callback invocation, accessibility source semantics, fresh storage and fixed clock,
and C01-only registry/gate behavior. This does not establish VoiceOver traversal.
The C01 UI test is separately opt-in via `WATT_C01_UI_TEST=1`, requiring an already
AX-authorized graphical host; it was not run here. No permission bypass attempted.
Production telemetry/helper wiring and charger-description metadata remain P01's
responsibility; this change does not alter that adapter or represent fixtures as
real readings. System font rendering and semantic label/accent colors vary by OS/host settings.

## Baseline verification before visual correction (2026-09-20)

- Native Debug build: passed (`build.log`); latest native test build also passed.
- Native XCTest: 110 executed, 1 opt-in P01 host probe skipped, 0 failures.
- Swift package XCTest: 110 executed, 1 identical skip, 0 failures.
- Release build + static analysis: passed (`release-analyze.log`).
- Release binary symbol check: no C01 fixture launch, registry, or capture types.
- C02 process launch: exit 1 before stores, `notImplemented("C02")`.
- `git diff --check`: passed. No separate SwiftLint configuration/run.
- App-owned dark capture: 640×946 pixels, 320×473pt, nonblank, existing Screen
  Recording permission. AX/VoiceOver/UI test not run.
- Pixel comparison: failed strict tolerance (changed fraction 0.9999801797),
  with explicit 2x→1x normalization and native/Figma material differences.
- Independent visual verification: **not run / pending**, no visual pass claimed.

Native test tooling emits macOS-13 deployment vs macOS-14 XCTest library warnings,
and host autoShortcut connection diagnostics; no test failures. No new dependencies,
P01 adapter edits, destructive operations or goal-state transitions were performed.


## Score-78 correction pass (2026-09-20)

**Ready for later independent vision review; no visual PASS claimed.** The prior
independent score of 78 is supplied by the task; this pass does not replace it
with a self-assigned score. Current PNGs, comparison, hashes and review input refer
to the correction; the unprefixed build/test logs above retain baseline history.

Only `StatusPanelView.swift` presentation changed: local named blue-violet surface
tokens drive an opaque native SwiftUI gradient, semantic label color supplies the
subtle card tint, perimeter and stronger separators, and local optical metrics
tune card/heading/footer spacing and label insets. Semantic text/accent styles,
light/increased-contrast system fallbacks, capability model and actions remain.
No desktop image, bitmap rendering substitute, shared screen styles or P01 changes.

Fresh correction evidence:
- `correction-build.log`: native Debug build **and static analysis succeeded**.
- `correction-native-tests.log`: F05FixtureTests **17 passed, 0 failures**.
- `correction-package-tests.log`: F05FixtureTests **17 passed, 0 failures**.
- `correction-script-checks.log`: bash syntax, ShellCheck and scoped diff checks passed.
- `capture.log`, `window.json`: app-owned window 7700, PID 99667,
  **320×473pt / 640×946px**, 1,524 sampled RGB colors.
- `comparison.json`: strict 1% pixel check **fails**, changed fraction
  **0.98878171247357294** (149,662 pixels); no masks, explicit 2x→1x resampling.
- No new VoiceOver/AX, UI automation, Release or all-suite verification in this
  focused pass. AppIntents metadata extraction emits its no-dependency warning.

The capture script now validates the pinned content/pixel geometry, regenerates
the normalized image, comparison derivatives and SHA-256 manifest, and accepts
only comparison exit 0 or diagnostic exit 2. Reference PNGs remain unmodified.

Focused verification:
```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test --scratch-path .build/c01-package --filter F05FixtureTests
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/c01-native build analyze
bash docs/evidence/C01/capture.sh
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/c01-native \
  test -only-testing:WattTests/F05FixtureTests -parallel-testing-enabled NO
bash -n docs/evidence/C01/capture.sh
shellcheck docs/evidence/C01/capture.sh
```

## Final focused score-88 correction (2026-09-20)

At this correction stage, the user-supplied independent verdict was **88/100 FAIL**.
The correction was submitted for independent review without self-assigning a new
score or PASS; the subsequent independent verdict is recorded below.
Current captures, comparison artifacts, hashes and review JSON replace the prior
correction evidence; earlier logs and entries above are historical.

Only `Features/MenuBar/Views/StatusPanelView.swift` presentation was changed:
native layered upper-right violet and diffuse diagonal gradient, semibold Components
heading using shared typography, summary line gaps reduced 2pt with compensating
card gap, 21pt outer/10pt inner card insets (preserving label/separator endpoints),
lower card/footer moved down 1pt, and reference #0091FF action blue for dark standard
appearance. Light/increased-contrast shared accent fallback remains. No model,
capability, accessibility, native-control, shared-token, P01 or other-screen edits.

Fresh results:
- `final-build-analyze.log`: Debug **BUILD SUCCEEDED**, **ANALYZE SUCCEEDED**.
- `final-native-tests.log`: focused F05FixtureTests **17 tests, 0 failures**.
- `final-package-tests.log`: focused F05FixtureTests **17 tests, 0 failures**.
- `final-script-checks.log`: bash syntax, ShellCheck, diff checks passed.
- `final-capture.log`, `capture.log`, `window.json`: app-owned dark capture,
  **320×473pt / 640×946px**; normalized derivative explicitly resampled to 320×473.
- `comparison.json`: strict 1% pixel diagnostic **FAIL**, changed fraction
  **0.9963332452431289**, **150805 pixels**; no masks.
  This is not a visual score; independent assessment was outstanding at this stage.
- Reference PNG hashes unchanged. No AX/VoiceOver or UI automation run.
- Existing XCTest deployment-target and no-AppIntents metadata warnings remain.


## Latest independent visual-ralph verdict (2026-09-20)

**92/100 — PASS**, as supplied by the independent reviewer verdict in the task.
Category match is **strong** for hierarchy, dimensions, card insets, separators
and footer. Close the C01 visual correction with **residual material/typography
differences**; this is not a claim of pixel identity or implementation self-approval.

The evidence is the exact panel crop of `reference-21-928.png` (panel `29:8875`),
**x551 y40 width320 height473**, against the app-owned dark `gallery-C01.png`
capture at **320×473pt / 640×946px**. `captured-panel-1x.png` is the explicitly
resampled **320×473** derivative (`sips -z 473 320`), not a raw 1x capture.
The original capture and existing SHA-256 hashes are retained unchanged.
The strict 1% pixel comparison remains **FAIL**, changed fraction
**0.9963332452431289** (150805 pixels), with no masks: a diagnostic, not approval.
Builds and tests likewise do not constitute visual approval.

Acceptance covers only the deterministic C01/base panel fixture, not the desktop,
system-owned selected status-item background or bolt anchor. **AX/VoiceOver
traversal and live interaction** (native MenuBarExtra opening/closing and live
Settings/Quit behavior) remain separate gaps; source semantics and callback tests
are not interaction sign-off. **Production telemetry/helper wiring and
charger-description metadata** remain separate P01 gaps; this fixture is not
proof of live readings. No new capture, source edits or accessibility/interaction
verification was performed for this documentation-only verdict update.
