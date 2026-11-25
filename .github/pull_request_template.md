## Summary

<!-- What changed, and why. -->

## Linked issue

Closes #

<!-- Delete the line above when this pull request has no issue. -->

## Change type

The title must be a [Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/). Release Please reads that title when this pull request is merged.

- [ ] `fix:` (patch)
- [ ] `feat:` (minor)
- [ ] `feat!:` or `BREAKING CHANGE` (major)
- [ ] `build:`, `chore:`, `ci:`, `deps:`, `docs:`, `perf:`, `refactor:`, `revert:`, `style:`, or `test:` (no version bump)

## Validation

- [ ] Unit tests pass (`swift test`, and `xcodebuild test` for `WattTests`)
- [ ] `xcodebuild` builds Debug and Release
- [ ] Lint passes (gitleaks secret scan)
- [ ] `python3 scripts/test_release_pipeline.py` passes, if `scripts/` or `.github/workflows/` changed
- [ ] UI changes were checked on macOS, and screenshots are attached

## Test plan

- [ ] Name the check, command, or case that covers this change
- [ ] Add any Mac check here, as another checkbox

## Assumptions to confirm

<!-- Delete this section when there is nothing to confirm. -->

- [ ] State what a reviewer should confirm

## Docs and changelog

- [ ] Docs updated (`README.md`, `RELEASING.md`, `CONTRIBUTING.md`, or another doc), or no doc update is needed
- [ ] Changelog left to Release Please, which rewrites `CHANGELOG.md` from this title. Edit `CHANGELOG.md` by hand only on a release pull request.
