# F02 gallery evidence

Latest successful pass: `reference-pass-2/` (2026-09-20).

| Specimen | Light and dark PNG dimensions | State |
|---|---|---|
| General (`light/`, `dark/`) | 1160 × 1960 | Disabled Components, Icon Only, buttons, focus, progress, separate off mini-switch |
| `reading-light/`, `reading-dark/` | 960 × 668 | Four enabled radios; Delta selected; exact watt descriptions |
| `settings-light/`, `settings-dark/` | 1160 × 964 | 580-point content; three groups; symbol on, smoothing on; helper On |

Each directory contains its PNG, `window.json`, and `gallery.sha256`. All captures are 2×, app-owned window only, en_US, fixed local fixtures. Screen recording access was preflighted without requesting permissions. Processes were terminated and waited after capture. No background capture/build job remains.

Reproduce: `bash scripts/capture-native-gallery.sh docs/verification/f02-gallery/<new-run-name>` (fails on reused directory). Retain native controls; do not substitute painted controls for pixel matching.

`final-checks/` contains retrieved contexts for Figma 27:1354 and 25:787, package test results (18 passed), Debug and Release build/analysis. Debug build and capture logs are in `reference-pass-2/`. Bash syntax, ShellCheck and diff whitespace checks passed. `reference-pass/` is an unsuccessful earlier build attempt, not acceptance evidence; older root light/dark captures are historical.

## Final independent specimen verdict (2026-09-20)

The fresh independent verdict supplied by the user is persisted in [visual-ralph-verdict.json](visual-ralph-verdict.json); this documentation pass did not re-score the images. It supersedes the earlier pending-acceptance status and prior scores for these four pairs only.

Scope: **F02 shared-component specimens**. Normalize at **2 px/point**, excluding desktop and window chrome.

| Pair | Figma node | Capture size (px) | Score | Verdict |
|---|---|---|---|---|
| reading-light | 27:1354 | 960 × 668 | 92 | PASS |
| reading-dark | 27:1354 | 960 × 668 | 91 | PASS |
| settings-light | 25:787 | 1160 × 964 | 90 | PASS |
| settings-dark | 25:787 | 1160 × 964 | 90 | PASS |

Reference SHA-256 hashes (verified against the retained PNGs):

- `27:1354` — `3aa05d431b7832a68d4ab80b84b5c0bd76092409904decdec4e0fa58a756525c`
- `25:787` — `a79e104cc77794e6695491b6bf97515c983ec47ea6d64f6dbae180a8945e52f2`

**`visual_threshold_met=true` applies only to this documented specimen gate, not screen completion. No backlog screen is declared done.**

### Limitations and retained evidence

- No calibrated numeric pixel diff was performed or fabricated. The verdict scores are not pixel-diff measurements.
- Accessibility evidence covers source-native semantics only; there is no VoiceOver or keyboard sign-off. Alert metadata records the dismissed initial state and native action roles, not a runtime confirmation audit.
- Minor geometry differences remain, including radio vertical rhythm, section spacing and native font/control widths. Do not attribute all residual differences solely to accepted OS chrome.
- Native picker/switch chrome, semantic colors and system font remain accepted platform treatment. Dark captures are semantic adaptations of the light references, not exact dark-reference matches.
- The refreshed captures retain the settings fixes: symbol on, C05 section spacing reduced from 16 to 6 points, and heading inset zero (shared default remains 4). The general gallery retains separate off-switch coverage; it is not an additional scored pair.

See [DESIGN.md](../../../DESIGN.md)'s F02 reference-backed specimen section for exact frame/content node mappings and accepted platform treatment.

## Native-control correction recapture — 2026-09-22

[Fresh current-source images and verification](../../evidence/native-styling/verification-2026-09-22/README.md)
use app-owned in-process rendering, not this directory's Screen Recording capture
script. These new images supersede old screenshots for current source; historical
2026-09-20 approvals above remain historical only. Native ownership passes, while
visual fidelity and active-window/accessibility acceptance remain unverified.
