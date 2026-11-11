# Contributing

Pull requests are welcome. Open one against `main`.

## Table of Contents

- [Issues](#issues)
- [Pull requests](#pull-requests)
- [Conventional commits](#conventional-commits)
- [Validation](#validation)
- [Security](#security)

## Issues

Bug reports and feature requests use the forms in `.github/ISSUE_TEMPLATE/`. Blank issues are turned off.

A bug report needs the macOS version, the Watt version, the Mac model, the steps, what you expected, what happened, and any logs you have. GitHub applies the `bug` label.

A feature request needs the problem, the proposed behavior, and the acceptance criteria. GitHub applies the `feature` label.

## Pull requests

Use the template in `.github/pull_request_template.md`. The description has a summary, a linked issue (`Closes #`), the change type, the validation checklist, and a note on docs and the changelog.

Delete the `Closes #` line when there is no issue.

## Conventional commits

This repository uses [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) because [Release Please](https://github.com/googleapis/release-please) cuts releases from the pull request title. The title check on every pull request rejects a title that Release Please cannot read.

`fix:` is a patch. `feat:` is a minor. `feat!:` or a `BREAKING CHANGE` footer is a major. These types do not bump the version: `build:`, `chore:`, `ci:`, `deps:`, `docs:`, `perf:`, `refactor:`, `revert:`, `style:`, and `test:`.

```text
type(optional-scope)!: description
```

`chore(main): release 1.0.1` is the title Release Please uses for its own pull request. The release steps are in [RELEASING.md](RELEASING.md).

## Validation

These checks run on every pull request, including every pull request into `main`. They are the checks to require before merge:

| Check | Workflow | What it runs |
| --- | --- | --- |
| `macOS` | Build and test | Debug and Release `xcodebuild` builds, `xcodebuild test` for `WattTests`, and `swift test`. A pull request also uploads the ad-hoc Release `Watt.app` as the `Watt-app-pr` workflow artifact for 7 days. |
| `Release config` | Release | `python3 scripts/test_release_pipeline.py` |
| `gitleaks` | Secret scan | Working-tree secret scan. The same scanner is the optional pre-commit hook in `.pre-commit-config.yaml`. |
| `Conventional commit` | PR title | The pull request title matches the types above |

Require those four checks. `Release Please`, `Build and publish`, `Update Homebrew cask`, and `Publish update endpoints` stay in the Release workflow and are skipped on a pull request that does not publish. A skipped required check blocks the merge.

Before you ask for review:

```sh
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' build
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' build
xcodebuild test -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -only-testing:WattTests
swift test
```

`WattUITests` drive the menu bar and are not part of the CI unit-test run. Run them on a Mac when you change that host.

If you change `scripts/` or `.github/workflows/`:

```sh
python3 scripts/test_release_pipeline.py
```

The lint check is the gitleaks secret scan.

CI gives `xcodebuild test` the same 120 second per-test allowance as `scripts/verify-native-host.sh`. The step stops the process after 10 minutes and retries once when `xcodebuild` does not exit. An assertion failure fails the check immediately.

UI changes need a manual check on macOS. Attach screenshots to the pull request.

Release Please writes `CHANGELOG.md` from the pull request title. Edit `CHANGELOG.md` by hand only on a release pull request. Update the docs when the change affects them.

## Security

Report a vulnerability privately through [GitHub Security Advisories](https://github.com/ben-ranford/watt/security/advisories/new). Do not put exploit details in a public issue. The same request is in the [README](README.md#reporting-a-vulnerability). This repository has no `SECURITY.md`. The issue chooser lists the bug and feature forms, and vulnerability reports use the advisory link above.
