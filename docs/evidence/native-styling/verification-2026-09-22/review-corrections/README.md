# Remaining native-styling review corrections — 2026-09-22

**Two concrete composition defects corrected; no full visual/AX acceptance.**
This follow-up supersedes the parent report's duplicate-field and helper-group
findings, not its other limitations. No checkpoint or commit was made.

## Changes and reference inspection

Inspected the parent's fresh light/dark settings and gallery-bottom captures and
retained Figma exports `docs/verification/f02-gallery/references/25-787.png`
(settings) and `27-1354.png` (reading). This is a comparison with retained exports,
not a claim of a new live Figma fetch or independent review.

- Gallery: removed the redundant `WattFormRow`/`Text` label around `TextField`.
  The native field supplies its single label; text, focus binding and identifier remain.
- Settings specimen: the menu-bar helper note is now the Menu Bar Section footer,
  rather than a standalone Form row. The previous rounded group was native Form
  styling caused by the wrong hierarchy, not a hand-drawn background. Its removal
  also removes the extra group's spacing without overriding native section spacing.
- Actual `SettingsRootView`: replaced padded nested VStacks with one grouped
  Form/Section, with existing shell explanation/status in the footer. All five
  placeholder labels remain; no real settings, navigation or persistence was added.
  Its existing 540×320 viewport is retained and the native Form can scroll.
- No custom backgrounds, gradients, clip shapes, button/picker chrome, dependencies
  or scene changes were introduced.

## Fresh captures

`capture.log` records 12 successful current-source renders at 2 px/point, using
in-process NSView caching, not desktop screenshots or TCC requests. All PNGs have
JSON metadata; hashes bind images, references and source/harness inputs.

| Specimen | Light | Dark |
|---|---|---|
| Gallery top | [light](controls-light.png) | [dark](controls-dark.png) |
| Gallery bottom, single field label | [light](controls-bottom-light.png) | [dark](controls-bottom-dark.png) |
| Settings sections, native footer | [light](settings-light.png) | [dark](settings-dark.png) |
| Actual Settings shell, top | [light](settings-shell-light.png) | [dark](settings-shell-dark.png) |
| Actual Settings shell, scrolled footer | [light](settings-shell-bottom-light.png) | [dark](settings-shell-bottom-dark.png) |
| Reading, unchanged control | [light](reading-light.png) | [dark](reading-dark.png) |

Visual inspection confirms one field label and no separate rounded group around
the settings note in both appearances. Shell bottom captures show the entire
footer after native scrolling; its last line is below the initial viewport.
The shell and reading include the genuine NSWindow frame to retain transparent
backing content; other specimens are content-only. Preliminary shell content-only
captures lost the backing surface and were replaced before final hashing.

Figma's note placement is now represented semantically by a section footer.
System headings/spacing/font metrics still differ from the reference; they were
not painted or pixel-tuned to hide platform differences. The production shell is
not the complete Figma Settings screen. No new pixel score or approval is claimed;
the parent's 82/100 and historical pixel comparisons describe only its earlier run.

## Verification

All final commands used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Check | Result | Log |
|---|---|---|
| `swift test --filter NativeStylingTests` | 5 passed | `package-focused.log` |
| `swift test` | 210 executed, 1 opt-in physical-telemetry skip, 0 failures | `package-full.log` |
| Hosted `-only-testing:WattTests/NativeStylingTests` | 5 passed | `native-focused.log` |
| Hosted `-only-testing:WattTests` | 210 executed, same skip, 0 failures | `native-full.log` |
| Debug `xcodebuild build` | succeeded | `debug-build.log` |
| Release `xcodebuild analyze` | succeeded | `release-analyze.log` |
| Capture compile/run | 12 captures, exit 0 | `capture.log` |
| Bash syntax, ShellCheck, whitespace, SHA-256 | passed | `static-checks.log` |

Hosted commands: `xcodebuild -project Watt.xcodeproj -scheme Watt -destination
'platform=macOS' -derivedDataPath .build/native-styling-review -configuration Debug
test -parallel-testing-enabled NO` plus the table's test selector. Result bundles:
`.build/native-styling-review/Focused-final.xcresult` and `Full-final.xcresult`.
Build uses Debug; analysis uses `-configuration Release analyze` with the same
project/scheme/destination/derived-data arguments. Reproduce captures with
`bash docs/evidence/native-styling/capture.sh <output-directory>`.

The added source regressions failed before implementation (`regression-before.log`).
An initial post-edit footer assertion was too whitespace-sensitive; it was changed
to normalize whitespace, retaining the footer/text adjacency requirement. Initial
failing runs remain in `*-first.log`; final `.exit` files are all 0 except the
intentional pre-change regression run (1). Existing preview deprecation, XCTest
minimum-version linker, package build-artifact and AppIntents warnings remain
nonfatal. SwiftLint is not installed; no new linter dependency was introduced.

## Remaining limits

Full **WattTests** means the hosted unit/integration target, not WattUITests UI
automation. No active-window accent/focus, pointer/keyboard, alert interaction,
VoiceOver, compositor-vibrancy or production-scene parity acceptance is claimed.
The host reports inactive windows; incomplete in-process AX traversal is not an
accessibility audit. Shell and specimen content are deliberately distinct.
