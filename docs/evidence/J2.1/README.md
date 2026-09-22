# J2.1 — Components unavailable in menu

- Figma node: `29:1549`.
- Status: **Blocked — native implemented; visual/TCC evidence pending**.
- Native implementation: `NSMenu`/submenu with rows **Delta** (checked), **Charger**, **Draw**, **Components** (disabled), **Icon**, and **Turn On Helper…**.

## Verification

Results supplied in the task; not rerun for this documentation-only update:

| Check | Result |
| --- | --- |
| Focused package tests | 4 pass |
| Focused hosted tests | 4 pass |
| Full package tests | 299 tests, 1 skipped, 0 failures |
| Hosted tests | 287 tests, 1 skipped, 0 failures |
| Debug build + analyze | Pass |
| Release build + analyze | Pass |
| Diff checks | Pass |

## Visual evidence blocker

No actual implementation capture exists. System-owned menu/compositor/AX/TCC blockers leave visual evidence pending. Automated verification does not prove visual parity. No pixel-diff claim is made.

`visual-review.json` records `score: null`, `verdict: blocked`, `category_match: unknown`, `visualPass: false`, and `storyDone: false`.
