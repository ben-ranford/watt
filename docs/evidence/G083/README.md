# G083 — Native grouped facts and button spacing

## Affected story and saved reference

- **J1.3 — Offer component readings**, exact Figma frame **27:1584**.
- Saved reference: [figma-frame.png](../J1.3/figma-frame.png),
  `docs/evidence/J1.3/figma-frame.png`, **1000×720 pixels**.
  The window crop is **480×412** at **(260, 164)**: window node `27:1738`,
  content node `27:1750`, rows node `27:2106`.
- [J1.3 evidence](../J1.3/README.md) retains the saved reference, earlier
  captures, metadata, hashes and historical review. Those historical results
  are not a new verdict for G083. No live Figma MCP retrieval is claimed.

## Production correction

The initial G083 button-spacing repair retained `.formStyle(.columns)` in
`OfferComponentReadingsView`. That flattened the facts instead of preserving
J1.3's grouped hierarchy; the earlier native content capture measured 480×317,
not the reference window's 480×412.

In `Features/Onboarding/Views/OnboardingFlowView.swift`, the latest correction
uses a native `Form` with `.formStyle(.grouped)` and three `LabeledContent`
rows: **What it reads**, **Network**, and **Remove it**. macOS owns the grouped
surface, separators and intrinsic row metrics; no custom-painted rows,
negative margins or forced row/form heights are introduced. Other onboarding
preview/login Forms retain their native columns style.

The earlier removal of extra horizontal `WattSpacing.xs` label padding remains:

- **Not Now**: native `.bordered` button, `onboarding.helper.notNow`.
- **Turn On…**: native `.borderedProminent` default-action button,
  `onboarding.helper.turnOn`.

Both buttons use OS-owned intrinsic spacing. Their actions, native styles and
accessibility identifiers remain unchanged.

## Verification — 2026-09-23

Fresh verification logs below use the local directory
`/tmp/watt-g083-final-verification-1790123494/` unless an absolute path is given.

| Check | Result | Evidence |
|---|---|---|
| J13OfferTests | **5 passed, 0 failures** | `package.log`; `/tmp/g083-j13-xcode-tests.log` |
| NativeStylingTests | **11 passed, 0 failures** | `package.log`; `/tmp/g083-native-tests.log` |
| Full Swift package suite | **704 tests, 5 skipped, 0 failures** | `/tmp/g083-full-tests.log` |
| Fresh Debug test build | **TEST BUILD SUCCEEDED**, exit 0 | `debug-tests.log`, `debug-tests.exit` |
| Fresh Release app build and analysis | **BUILD SUCCEEDED**, **ANALYZE SUCCEEDED**, exit 0 | `release-app.log`, `release-app.exit` |
| Fresh Release test build | **TEST BUILD SUCCEEDED**, exit 0 | `release-tests.log`, `release-tests.exit` |
| Diff whitespace | **git diff --check passed** | Rerun for this documentation update |

Test builds are compilation checks, not additional test executions. These
results were checked against existing logs; this documentation-only update
did not rerun tests or builds.

## Native capture and manual inspection

The corrected capture is in `/tmp/g083-j13-grouped-1790123119/`:

- `actual-content.png`: **480×412 pixels**, with `capture.json` metadata.
- `native-window.png`: **960×824 pixels at 2x**, representing a **480×412-point**
  native window; `window.json` records those window bounds and
  `window-capture.log` records the PID-scoped capture.

Manual inspection against the saved J1.3 frame confirms the grouped facts
hierarchy, the 480×412 window dimensions and native controls. This is a
structural and dimensional confirmation, not pixel-identical parity. The
native window image supplies the visible window chrome; the cached content
capture does not assess the native titlebar.

These `/tmp` artifacts are local and temporary. This documentation update does
not copy or replace saved reference evidence or create a new capture.

## Visual and accessibility limits

Desktop wallpaper, menu bar, clock and other surrounding desktop context are
OS-owned, not app-rendered acceptance targets. Native typography, control
spacing, grouped Form insets, row metrics and window chrome can vary with
macOS; matching the window dimensions does not establish pixel equality.

**No pixel-diff score, strict same-scale visual parity, or independent
accessibility pass is claimed.** Capture metadata retains `visualPass: false`;
manual inspection does not convert it into an automated comparison or an
overall visual/AX gate pass. Earlier `.columns` geometry/scale comparison
failures are historical, not comparison results for this grouped capture.

The fixture uses isolated in-memory state and no live services. No live
AX/VoiceOver audit, helper approval or TCC verification is claimed. No
permission prompt or TCC bypass was attempted for this documentation update.
