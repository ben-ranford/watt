# G021 / C04.7 — Component-selection status item

Retained evidence, 2026-09-22. Native fixture and automated checks are recorded
below; **visual acceptance remains open**. This documentation update does not
rerun tests, builds or capture. No commit or checkpoint.

## Exact reference and native contract

Figma file `9DKDgUfEqidZdZQEVlQgLS`: frame **24:1234**, component **24:1350**,
anchor **24:1352**. The retained reference is `reference-24-1234.png`.
The component occupies **x153,y5,148×24** in the **560×44** frame, ending at x301.

- The native `MenuBarStatusLabel` displays **`CPU 9.8 · GPU 4.1 W`**, without
  a symbol. Its accessibility value is `CPU 9.8 · GPU 4.1 watts`.
- DEBUG selectors `C04.7` and `C04.7/base` use `samplePerComponent`, available
  component readings, fixture source, a timestamp-pinned clock and isolated
  in-memory preferences in `.components` mode. CPU/GPU selection is ordered.
- The existing max-two contract allows at most two distinct, nonblank component
  IDs. An invalid three-component assignment preserves the previous selection.
  A single selection renders `CPU 9.8 W`; empty selection renders `—`;
  a missing component renders its ID followed by `—`.
- One trailing unit is shared only for explicit `.perComponent` readings when
  all selected values are available. Legacy charging/C03 formatting retains
  `CPU 9.8 W · GPU 4.1 W`; existing native typography is reused.

## Retained verification

These results come from existing logs, not new executions for this update.

| Check | Recorded result | Evidence |
| --- | --- | --- |
| Focused package C041–C047 | 26 passed, 0 failures | [package-focused.log](package-focused.log) |
| Focused native hosted C041–C047 | 26 passed, 0 failures | [native-focused.log](native-focused.log) |
| Full package suite | 234 executed, 1 skipped, 0 failures | [package-full.log](package-full.log) |
| Full native hosted suite | 234 executed, 1 skipped, 0 failures | [native-full.log](native-full.log) |
| Debug build and analysis | Both succeeded | [debug-build-analyze.log](debug-build-analyze.log) |
| Release build and analysis | Both succeeded | [release-build-analyze.log](release-build-analyze.log) |
| Bash syntax, ShellCheck, diff whitespace | Passed | [static-checks.log](static-checks.log) |

The skipped test is the opt-in physical-host metadata probe, not fixture evidence.
Focused coverage includes exact selectors/capture isolation, deterministic native
text, selection order/max-two behavior, preserved legacy formatting and geometry.

## Capture and strict comparison

[Capture metadata](capture.json) and [capture log](capture-run.log) record a real
app-owned **NSStatusBarButton** hosting the native label, relocated into a
synthetic dark bounded host. Explicit DEBUG capture suppresses MenuBarExtra.
`actual-status-item-1x.png` is a direct **560×44-pixel / 560×44-point** AppKit
bitmap without resampling. `actual-status-item.png` is a separate **1120×88**
screen-scale diagnostic, not the comparison input. AppKit button y15 corresponds
to reference top-origin y5. Both item crops retain **148×24** source pixels.

Retained [capture script](capture.sh), [comparison script](compare.sh),
[normalization log](normalization.log), [comparison log](compare-run.log), raw
PNGs, crop metadata, diff/overlay images and [SHA-256 manifest](images.sha256)
provide the capture/compare record. Scripts were not rerun for this update.

Both strict, unmasked comparisons **fail** at tolerance **0.01**:

| Scope | Changed pixels | Fraction | Report |
| --- | --- | --- | --- |
| Full frame | 24,640 / 24,640 | 1.0 | [frame-comparison.json](frame-comparison.json) |
| Component | 3,552 / 3,552 | 1.0 | [item-comparison.json](item-comparison.json) |

Both reports retain `pass: false` and `storyDone: false`; both diagnostics exit
2. The comparison wrapper accepts that diagnostic exit to retain artifacts,
not to declare visual success.

**Independent visual review is pending.** No independent score or approval is
claimed. A relocated native button and synthetic backdrop do not prove live
MenuBarExtra/compositor pixels, desktop context or global placement. Native
rasterization parity, AX/VoiceOver traversal, physical interaction and real
telemetry remain unproven by these artifacts. Render-target availability and
passing automated tests are not story completion.
