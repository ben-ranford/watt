# G043 / J3.3 — Helper needs updating after app update

## Exact source and control hierarchy
Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `29:6181`. [reference.json](reference.json) pins the supplied 1000×720 light reference, asset URL and SHA-256; [figma-reference.png](figma-reference.png) matches that hash. Existing metadata records design-context retrieval; this documentation pass inspected the pinned image, not a new Figma export.

Reference order, top to bottom:
1. App-icon placeholder above the text.
2. **The helper changed**
3. “Watt? 1.1 comes with a new helper. macOS asks you to approve it once more.”
4. **Update Helper** — blue primary/default action.
5. **Later** — secondary/cancel action.

The reference includes desktop wallpaper and a menu bar. Those are macOS-owned context, not app controls or assets to reproduce.

## Native Alert mapping and behavior
- `App/HelperUpdatePresentation.swift` attaches SwiftUI `.alert` to content: the title and message use the exact strings above; native `Button` controls map Update Helper to `.keyboardShortcut(.defaultAction)` and Later to `role: .cancel`. macOS owns alert material, typography, button geometry and ordering; no custom alert frame, icon image or painted chrome is supplied by this modifier. Source semantics are verified; Return/Escape and VoiceOver operation are not live-verified.
- `App/RootSceneView.swift` presents the alert from `UpdateRootView`. Later dismisses the update scene and routes to the status panel without calling either update boundary or changing preferences. The scene exposes pending approval with **Check Approval**, failures with **Retry**, and rechecks pending approval when active.
- `HelperUpdatePrompt.configure` connects verified `UpdateAdapter` relaunch recovery to `HelperLifecycleAdapter.update`. An unverified relaunch cannot invoke the helper update. Retries retain the operation receipt; duplicate work is guarded, and cancelled/closed generations ignore late replies. Pending approval is not connected; installation proof, renewed approval and authenticated reconnect are required. An old helper protocol is unsupported, not silently migrated. These boundaries are proven with injected tests, not a live signed installation.
- The DEBUG `J3.3/base` fixture uses an `NSWindow` hosting the real `UpdateRootView` and in-memory preferences. It does not configure live updater/helper boundaries and disables its approval-settings callback. The capture proves native presentation only, not successful Update Helper or Later interaction.

## Recorded verification
The following totals come from the existing logs and companion exit files, not tests rerun during this documentation-only pass. Counts overlap across runs and must not be summed as distinct coverage.

| Evidence | Recorded result |
| --- | --- |
| [focused-tests.log](focused-tests.log) | 54 tests, 0 failures: J33HelperUpdateTests 10, P02HelperLifecycleTests 13, P04UpdaterTests 31; exit 0 |
| [package-tests.log](package-tests.log) | 369 tests, 1 skipped, 0 failures; exit 0 |
| [package-build.log](package-build.log) | Build complete; exit 0 |
| [host-Debug.log](host-Debug.log) | Build and analyzer succeeded; exit 0 |
| [host-Release.log](host-Release.log) | Build and analyzer succeeded; exit 0 |
| [host-tests.log](host-tests.log) | 357 tests, 1 skipped, 0 failures; exit 0; restricted to `-only-testing:WattTests`, **not UI tests** |
| [capture-final/window-capture.log](capture-final/window-capture.log) | Two PID-scoped app-owned windows captured; capture exit 0 |
| [diff-check.log](diff-check.log) | No whitespace errors; exit 0; refreshed after documentation edits |

The skipped test in both full unit-test runs is `P01TelemetryTests.testPhysicalHostPublicAPISmoke`, an opt-in physical-host probe. Package logs retain unhandled-file warnings; Xcode logs retain destination/metadata warnings. Passing builds do not mean warning-free builds, and no separate lint run is recorded.

## Native capture and Visual-Ralph verdict — BLOCKED
[visual-review.json](visual-review.json) records `score: null`, `verdict: blocked`, `visualPass: false`, and `storyDone: false`.

[Final window metadata](capture-final/window.json) records fixture `J3.3/base`, PID 42174, screen capture preauthorized, `AXTrusted: false`, and `liveInteractionVerified: false`. The capture script enumerates that PID's on-screen windows and captures their window IDs without desktop capture or new permission requests. Its fixed `capture-final` directory already exists; this pass did not rerun or overwrite the capture.

- [native-window-11324.png](capture-final/native-window-11324.png): 560×440 pixels; compositor entry 11324 has 260×188 bounds.
- [native-window-11323.png](capture-final/native-window-11323.png): 560×440 pixels; entry 11323 is titled “Watt? Update” with 280×88 bounds.

Both PNGs visibly include the dark alert and host-window title bar; neither is an isolated crop matching its individual compositor bounds. The title, full message and stacked Update Helper / Later order are visible. This is real native render evidence, but not comparable light visual acceptance: the reference has a light, icon-bearing alert over a desktop; the captures have dark material, no visible app icon, host title-bar chrome, and different message wrapping/geometry. No aligned crop, pixel diff, overlay or similarity score was produced. The PNGs are retained unmodified; reference pixels are not substituted for actual output. `reference.json`'s `nativeRenderVerified: false` is retained conservatively, not promoted to a visual pass by capture success.

Remaining gates: comparable light native capture and review; AX/keyboard/VoiceOver and action interaction; live signed app relaunch, helper installation, renewed macOS approval and authenticated reconnect. The existing blocked backlog status remains correct. No production readiness or story completion is claimed.
