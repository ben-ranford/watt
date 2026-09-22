# C02 / G013 — On battery (light)

## Independent visual review — 92/100 PASS

Previous independent score: **88/100 FAIL** (flat cool-gray surface). Replaced only
standard-light panel fill with native warm beige/gray layered diagonal gradients.
No geometry, typography, action alignment, controls, C01 dark drawing, shared
semantic tokens, or other screens changed.

Fresh verification: package C02 tests **4 passed**; native F05/C01/C02 tests
**21 passed**; Debug build/analyze passed; owned-window capture remains exactly
320×473pt (640×946px). Comparison/images/hashes regenerated. Strict pixel diagnostic
still fails; this is not a perceptual verdict.

The fresh independent visual-ralph verdict supplied with this task is **92/100 PASS**.
Content, typography, hierarchy, spacing, card-row layout, the “Unplugged” state,
components and footer match strongly. Residual differences are weaker diagonal
luminance, weaker perimeter highlight and minor rasterization differences. This
closes the C02 visual correction, not pixel-identical or whole-story approval.
See `visual-review.json` for the verdict and exact evidence scope. `review-input.json`
retains the pre-review handoff and immutable image identities; its pending status
is historical, superseded by this verdict.

The verification table below records the prior implementation baseline; full-suite
and Release checks were not rerun for this surface-only correction.

## Scope and design

Exact Figma file 9DKDgUfEqidZdZQEVlQgLS, frame 22:130, panel 29:9158.
See DESIGN.md C02 section for hierarchy, typography, spacing, tokens and exact copy.
`figma-context.json` is the retrieved MCP panel context including screenshot;
`figma-hierarchy.xml` retains the panel subtree from the supplied F00 metadata.
The original export is copied unchanged to `reference-22-130.png`.
Its exact 320×473 source-pixel crop at x551/y40 is `reference-panel.png`, without
resampling; `reference-panel.png.json` records the crop metadata.
System desktop/menu-bar chrome outside that crop is excluded.

C01 StatusPanelView and tokens are reused. C02 adds a DEBUG stable on-battery
fixture and native launch selection before store construction. C01 charging
copy/values/dark layout remain unchanged and covered by regression tests.
Only C01/C02 selectors render. Other selectors still fail before store creation.
Settings uses the existing router; Quit uses native application termination.
Unit tests invoke supplied callbacks; they are not an end-to-end click audit.
Existing unrelated uncommitted implementation work was preserved.

## Evidence

- `gallery-C02.png`: raw app-owned light/aqua 640×946px window capture.
- `window.json`: 320×473pt, 2 pixels/point, en_US, PID/title/window identity,
  OS version and nonblank check. Uses already-granted Screen Recording access.
- `captured-panel-1x.png`: explicit 640×946px to 320×473px sips-resampled
  derivative used for review, not raw 1x capture; raw capture remains retained.
- `visual-review.json`: supplied independent visual-ralph 92/100 PASS verdict;
  panel-only C02/base fixture evidence, not accessibility or live-service approval.
- `comparison.json`, overlay/diff: equal-scale 1px/point comparison, no masks.
- `images.sha256`: raw reference, crop, raw capture and comparison image hashes.
- `capture.swift`: C02-local adaptation of C01 ownership/geometry-checked capture.
  It preflights existing permission; never requests TCC/AX or captures the desktop.
- `rejected-C03.log`: native process exit 1, notImplemented("C03").
- `release-isolation.log`: no C01/C02 fixture/registry/capture symbols or launch
  strings in the Release binary.

## Verification results

| Check | Result |
| --- | --- |
| Package focused F05/C01/C02 | 21 passed |
| Native focused F05/C01/C02 | 21 passed |
| Package full unit suite | 195 executed, 1 opt-in P01 host probe skipped, 0 failures |
| Native full unit suite | 195 executed, same skip, 0 failures |
| Native Debug build + analyze | Passed |
| Native Release build + analyze | Passed |
| Bash syntax / ShellCheck / git diff --check | Passed |
| App-owned exact light geometry / nonblank | Passed |
| Strict pixel comparison | Failed (changed fraction 0.96471326638477806, tolerance 0.01); diagnostic only |
| AX/VoiceOver/UI runner | Not run; no authorization bypass |

Builds provide Swift compiler/type checking and Xcode static analysis.
No separate SwiftLint configuration was introduced. Existing AppIntents metadata
and XCTest deployment-target warnings are retained in logs.

## Reproduction (repository root)

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test --scratch-path .build/c02-package --filter F05FixtureTests
swift test --scratch-path .build/c02-package
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/c02-native build analyze
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/c02-native \
  test -only-testing:WattTests/F05FixtureTests -parallel-testing-enabled NO
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/c02-native \
  test -only-testing:WattTests -parallel-testing-enabled NO
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release \
  -destination 'platform=macOS' -derivedDataPath .build/c02-release build analyze
xcrun swiftc scripts/F05/image-evidence.swift -o .build/c02-image-evidence
.build/c02-image-evidence crop docs/evidence/C02/reference-22-130.png \
  docs/evidence/C02/reference-panel.png 551 40 320 473
bash docs/evidence/C02/capture.sh
bash -n docs/evidence/C02/capture.sh
shellcheck docs/evidence/C02/capture.sh
git diff --check
```

## Explicit remaining gaps

Production P01 telemetry/helper wiring remains unchanged: these numbers are fixtures,
not proof of production sampling or hardware component capabilities. Ordinary app
composition still uses its existing preview store; this task does not fix that gap.
Native MenuBarExtra entry is retained, but opening the actual popover, Settings/Quit
clicks, focus/keyboard traversal, AX tree and VoiceOver behavior were not audited.
The visual PASS applies only to the exact light/aqua C02/base panel images above;
it excludes desktop/menu-bar chrome and native status-item appearance. System
colors/fonts/materials vary with host OS and settings. AX/VoiceOver and live
interaction verification, and production P01 telemetry/helper limitations, remain
separate and are not resolved by this visual verdict. This documentation-only
update did not rerun builds, tests or capture, or perform a new visual review.
No goal-state or ultragoal checkpoint was performed.
