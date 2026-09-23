# G083 — Native grouped facts and button spacing

## Affected story and saved reference

- **J1.3 — Offer component readings**, exact Figma frame **27:1584**.
- Saved reference: [figma-frame.png](../J1.3/figma-frame.png),
  `docs/evidence/J1.3/figma-frame.png`, **1000×720 pixels**.
  The window crop is **480×412** at **(260, 164)**: window node `27:1738`,
  content node `27:1750`, rows node `27:2106`.
- [J1.3 evidence](../J1.3/README.md) retains the saved reference, earlier
  captures, metadata, hashes and historical review. Those historical results
  are not a new verdict for G083. The current Figma MCP reinspection is
  recorded in [figma-mcp-reinspection-2026-09-23.md](figma-mcp-reinspection-2026-09-23.md).

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

The latest width correction gives the header and action row independent
**32-point horizontal insets**. The grouped `Form` is their sibling, with a
positive horizontal `WattSpacing.md` inset (**12 points**), rather than nested
inside their 32-point inset. Combined with the native Form inset, the visible
facts group starts at **x32** and spans **416 points**, matching the reference.
No negative compensation or forced row heights are used.

The earlier removal of extra horizontal `WattSpacing.xs` label padding remains:

- **Not Now**: native `.bordered` button, `onboarding.helper.notNow`.
- **Turn On…**: native `.borderedProminent` default-action button,
  `onboarding.helper.turnOn`.

Both buttons use OS-owned intrinsic spacing. Their actions, native styles and
accessibility identifiers remain unchanged.

## Verification — 2026-09-23

The latest post-review verification logs are preserved in [logs/](logs/),
relative to this README. Focused tests, the full suite and static checks came
from `/tmp/watt-g083-layout-postreview-1790124916/`. Existing Debug
build/analysis logs came from `.build/j13-verification/`; Release logs came
from `/tmp/watt-g083-layout-verification-1790124426/`.

| Check | Result | Evidence |
|---|---|---|
| Exact Figma MCP reinspection | **PASS** — node `27:1584`, hierarchy, variants and typography recorded | [figma-mcp-reinspection-2026-09-23.md](figma-mcp-reinspection-2026-09-23.md) |
| Current Debug app build and analysis | **BUILD SUCCEEDED**, **ANALYZE SUCCEEDED** | [current-build-analyze.log](logs/current-build-analyze.log) |
| Current focused Xcode J13OfferTests + NativeStylingTests | **16 passed, 0 failures** | [current-xcode-focused.log](logs/current-xcode-focused.log) |
| Current F05 launch-gate regression | **22 passed, 0 failures** | [current-f05.log](logs/current-f05.log) |
| Current full Xcode WattTests suite | **704 tests, 5 skipped, 0 failures** | [current-xcode-full.log](logs/current-xcode-full.log) |
| Current static checks and whitespace | **PASS** | [current-static-checks.log](logs/current-static-checks.log) |
| Post-review focused J13OfferTests + NativeStylingTests | **16 passed, 0 failures** | [test-green.log](logs/test-green.log) |
| Latest Debug app build and analysis | **BUILD SUCCEEDED**, **ANALYZE SUCCEEDED** | [build-analyze.log](logs/build-analyze.log) |
| J13OfferTests | **5 passed, 0 failures** | [test-green.log](logs/test-green.log) |
| NativeStylingTests | **11 passed, 0 failures** | [test-green.log](logs/test-green.log) |
| Post-review full Swift package suite | **704 tests, 5 skipped, 0 failures** | [full-package.log](logs/full-package.log) |
| Post-review static checks | **PASS** | [static-checks.log](logs/static-checks.log) |
| Fresh Release app build and analysis | **BUILD SUCCEEDED**, **ANALYZE SUCCEEDED** | [release-app.log](logs/release-app.log) |
| Fresh Release test build | **TEST BUILD SUCCEEDED** | [release-tests.log](logs/release-tests.log) |
| Diff whitespace | **git diff --check passed** | Rerun for this documentation update |

Test builds are compilation checks, not additional test executions. The current
verification uses the full Xcode toolchain because the standalone Command Line
Tools SwiftPM path cannot load the system `SwiftUIMacros` plugin on this host.
The current production onboarding source and focused native-styling tests are
unchanged from `main`; the only source change in this refresh is the F05 test
allowlist correction that makes the existing J10.4/J10.5/J12.3/J12.4
non-base launch-gate contract explicit. The committed capture therefore still
represents the current production view. Existing visual verdict artifacts were
not silently replaced.

## Latest native capture and independent visual review

- Fresh capture: [exact-window.png](capture/exact-window.png), **960×824 pixels
  at 2x**, representing a **480×412-point** window.
- Content capture: [actual-content.png](capture/actual-content.png), **480×412
  pixels**; this cached content capture does not assess the native titlebar.
- Capture evidence: [window.json](capture/window.json),
  [capture.json](capture/capture.json),
  [window-capture.log](capture/window-capture.log) and
  [pixel-inspection.txt](capture/pixel-inspection.txt).
- PNG checksums: [images.sha256](capture/images.sha256), with filenames relative
  to `capture/`.
- Saved reference: `docs/evidence/J1.3/figma-frame.png`, using the **480×412**
  window crop above. The fresh capture was normalized to **480×412** for the
  direct comparison.
- Fresh independent verdict: **94/100 — PASS**, threshold **90**,
  `category_match: true`; persisted in [visual-review.json](visual-review.json)
  from a fresh independent vision review of the current commit, not a new
  review performed by this documentation update.

The **x32 / 416-point** facts width aligns. Content, hierarchy, header and
native actions are consistent; grouped facts hierarchy and native button
spacing are materially correct. The facts group remains approximately
**15 points lower and 16 points shorter** than the reference (**y229 / 110-point
height** versus **y214 / 126-point height**). Native buttons are narrower, with
approximately **8-point spacing** versus **10 points** in the reference.
This residual native vertical compression does not materially compromise the
composition. Retain the corrected width and native actions; do not force row
heights.

Accepted differences include native traffic-light rendering and inactive zoom,
native button dimensions, corners and font rendering, and desktop background
and shadow. The review accepts these native metrics rather than claiming
pixel-perfect parity.

## Historical native capture and manual inspection

The earlier grouped capture is in `/tmp/g083-j13-grouped-1790123119/`:

- `actual-content.png`: **480×412 pixels**, with `capture.json` metadata.
- `native-window.png`: **960×824 pixels at 2x**, representing a **480×412-point**
  native window; `window.json` records those window bounds and
  `window-capture.log` records the PID-scoped capture.

Manual inspection against the saved J1.3 frame confirms the grouped facts
hierarchy, the 480×412 window dimensions and native controls. This is a
structural and dimensional confirmation, not pixel-identical parity. The
native window image supplies the visible window chrome; the cached content
capture does not assess the native titlebar.

The historical `/tmp` artifacts remain local and temporary. The latest
width-corrected capture and verified logs are now preserved in `capture/` and
`logs/`. Their contents retain original capture-time metadata and local paths
for provenance. This update does not replace saved reference evidence or
create a new capture.

## Visual and accessibility limits

Desktop wallpaper, menu bar, clock and other surrounding desktop context are
OS-owned, not app-rendered acceptance targets. Native typography, control
spacing, grouped Form insets, row metrics and window chrome can vary with
macOS; matching the window dimensions does not establish pixel equality.

**No calibrated pixel-diff score, pixel-perfect parity, independent AX audit
or TCC verification is claimed.** The **94 PASS** is the verdict from a fresh independent
vision review of the current commit: visual-only, not an automated similarity score or an overall visual/AX
gate pass. Capture metadata retains `visualPass: false` as unchanged
capture-time metadata; the later verdict is recorded separately in
`visual-review.json`. Earlier `.columns` geometry/scale comparison failures
and the earlier grouped manual inspection remain historical, not the verdict
for the fresh width-corrected capture.

The fixture uses isolated in-memory state and no live services. No live
AX/VoiceOver audit, helper approval or TCC verification is claimed. No
permission prompt or TCC bypass was attempted for this evidence refresh.
