# G083 — Native button intrinsic spacing

## Affected story and saved reference

- **J1.3 — Offer component readings**, Figma frame **27:1584**.
- Existing reference: [figma-frame.png](../J1.3/figma-frame.png), **1000×720 pixels**.
  The window crop is **480×412** at **(260, 164)**: window node `27:1738`,
  content node `27:1750`, rows node `27:2106`.
- [J1.3 evidence](../J1.3/README.md) retains the saved reference, earlier
  captures, metadata, hashes and historical review. Those results are not a
  new visual verdict for G083. No new Figma MCP retrieval is claimed.

## Production correction

In `Features/Onboarding/Views/OnboardingFlowView.swift`,
`OfferComponentReadingsView` removes the extra horizontal `WattSpacing.xs`
label padding from both production actions:

- **Not Now**: native `.bordered` button, `onboarding.helper.notNow`.
- **Turn On…**: native `.borderedProminent` default-action button,
  `onboarding.helper.turnOn`.

Both buttons now use OS-owned intrinsic spacing. Their actions, native styles
and accessibility identifiers remain unchanged.

## Verification — 2026-09-23

| Check | Result | Evidence |
|---|---|---|
| NativeStylingTests | **11 passed, 0 failures** | `/tmp/g083-native-styling.log` |
| Debug xcodebuild | **BUILD SUCCEEDED** | `/tmp/g083-xcode-build.log` |
| Debug capture build | **BUILD SUCCEEDED**, exit 0 | `/tmp/g083-j13/build.log`, `build.exit` |
| Diff whitespace | **git diff --check passed** | Rerun for this documentation update |
| Fresh native capture and inspection | **Succeeded**; 960×634 px, 480×317 pt | `/tmp/g083-j13/native-window.png`, `window.json`, `window-capture.log`, `capture.exit` |

The fresh content capture is `/tmp/g083-j13/actual-content.png` at 480×317
pixels, with metadata in `capture.json`. Inspection evidence also includes
`button-measurements.txt`. These `/tmp` artifacts are local and temporary;
this documentation update does not copy or replace saved reference evidence.
The test/build results above were checked against existing logs, not rerun
by this documentation-only update.

## Visual and accessibility limits

**Strict/same-scale visual parity was not established.** The fresh native
window is 960×634 pixels at 2x (480×317 points), while the saved reference is
1000×720 pixels with a 480×412 window crop. Content geometry differs.

`/tmp/g083-j13/native-comparison.log` reports “Scale mismatch or invalid
tolerance”; `content-comparison.log` reports “Geometry mismatch; resizing is
forbidden”. Both comparisons exited 1. Successful capture and inspection do
not constitute a visual pass or a same-scale parity result.

**No visual pass or accessibility sign-off is claimed for G083.** The fresh
capture metadata records `visualPass: false`; no AX/VoiceOver audit is claimed.
