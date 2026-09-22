# G017 / C04.3 — Delta · fully charged

Bounded native-render evidence, 2026-09-22.
**Visual acceptance remains open. No checkpoint, commit or story-completion claim.**

## Exact reference

- Frame **24:758**, component **24:874**, anchor **24:876**.
- Reference: `reference-24-758.png`, exact **560×44** pixels at 1×;
  SHA-256 `d45b3201b8c62558b68373bb07d05b1bd3c6e1e1966abe823df9c2b8927b1f37`.
- Component crop: **81×24** at top-left **x220,y5**, ending at x301,
  recorded in `reference-item.png.json`.
- Native label contract: SF Symbol `battery.100percent.bolt` plus **`0.0 W`**.

## Evidence scope

This README records existing C04.3 artifacts and logged verification only;
source code was not inspected or changed for this documentation task.
`capture.json` identifies `C04.3/base` and a real app-owned `NSStatusBarButton`
hosted by a DEBUG NSStatusItem, with MenuBarExtra suppressed for capture.

## Native capture and comparison

Retained reproduction scripts: `capture.sh` and `compare.sh`; corresponding
outputs are `capture-run.log` and `compare-run.log`.

- `capture.json` records an exact **560×44-point** host and direct
  **560×44-pixel / 560×44-point** bitmap, with `resampled: false`.
- `actual-status-item-1x.png` is the direct AppKit view-subtree render via
  `NSView.displayIgnoringOpacity(_:in:)`, not a resized screenshot.
- `actual-status-item.png` is the separate **1120×88** screen-scale
  `NSView.cacheDisplay` diagnostic.
- The relocated button frame is AppKit bottom-left **(220,15),81×24**,
  corresponding to reference top-left **(220,5)**.
- `reference-item.png` and `actual-item.png` retain unresampled **81×24** crops.
- `frame-comparison.json` and `item-comparison.json` both **FAIL**:
  changedFraction **1.0**, tolerance **0.01**, no mask, `storyDone: false`.
  Frame: 24,640 changed pixels; component: 1,944 changed pixels.
  Diff/overlay PNGs and `images.sha256` are retained alongside the inputs.

Independent visual review: **88/100 component similarity**, as supplied for
this documentation task. This subjective component score is not a passing
pixel comparison or end-to-end acceptance. A separate C04.3 review artifact
was not present among the inspected evidence files.

**Visual acceptance remains open.** The app-owned native capture cannot prove
live MenuBarExtra compositor pixels, global menu-bar placement, accessibility
(AX)/VoiceOver traversal, physical interaction, or TCC-authorized desktop capture.
The synthetic dark backdrop omits live wallpaper and neighboring system items.
Direct 1× destination dimensions do not establish AppKit/SwiftUI internal layer
rasterization scale or pixel parity. Do not treat this bounded render as live
compositor/AX/TCC proof or infer permission grants from it.

## Recorded verification

Results below are from existing logs; no tests or builds were rerun for this
 documentation-only update.

- `package-focused.log`: **13 passed**, zero failures — C041: 5,
  C042: 4, C043: 4.
- `native-focused.log`: same **13 passed**, zero failures;
  **TEST SUCCEEDED**.
- `package-full.log`: **221 executed, 1 skipped, 0 failures**.
- `native-full.log`: **221 executed, 1 skipped, 0 failures**;
  **TEST SUCCEEDED**.
- `debug-build-analyze.log` and `release-build-analyze.log`:
  **BUILD SUCCEEDED / ANALYZE SUCCEEDED** in both configurations.
  Commands use `-project Watt.xcodeproj -scheme Watt -destination
  'platform=macOS'`, with `.build/c043-native` and `.build/c043-release`
  derived-data directories respectively.
- `release-isolation.log`: PASS — no C04.3 fixture/sample/capture selectors
  in the Release binary.
- `static-checks.log`: PASS — Bash syntax and ShellCheck.
- Logged warnings include unhandled Swift package files, skipped AppIntents
  metadata extraction without a framework dependency, and hosted UI-test
  linking against newer macOS XCTest/XCUIAutomation libraries.

Stop condition: documentation written from retained evidence and supplied review
score. Visual acceptance is not granted; no commit or checkpoint.
