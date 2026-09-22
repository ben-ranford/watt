# G064 / J9.3 — After Quit

Exact node `32:6494`, no app-owned after-quit surface. See `reference.json` and
`figma-{context,metadata,screenshot}.json`. Both PNG hashes match (`reference.sha256`).

## Files changed for this story
- `App/WattApp.swift`: delegate termination cleanup, representable teardown, stale
  queued panel guard, Debug fixture composition; sole SwiftUI status-item ownership retained.
- `App/J93FixtureLaunch.swift`: isolated Debug-only native Quit observation.
- `Tests/WattTests/J93AfterQuitTests.swift`: six focused lifecycle/native-composition tests.
- `Tests/WattTests/F05FixtureTests.swift`: implemented registry expectation.
- `Tests/Fixtures/{StoryFixtures,FixtureLaunchSelection}.swift`: exact J9.3 selector
  and honest native-termination fixture policy.
- `Watt.xcodeproj/project.pbxproj`: fixture and test source membership.
- `DESIGN.md`, `SCREEN-BACKLOG.md`, `docs/evidence/J9.3/*`: contract and evidence.

## Automated results
17 focused tests pass; 578 full package tests, 5 skipped, zero failures.
Debug build/analyze/test-build and Release build/analyze pass; static checks and
Release fixture isolation pass. Xcode toolchain required (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`).
Final `.exit` files and logs are retained. `preflight-tests.log` records the initial
CLT mismatch; `full-tests-first.log` records the fixed registry expectation failure.
Native test targets compile; no unbounded native test host was launched.

## Native evidence limits
`capture.py` launched the exact built bundle from a unique temporary directory under
`~/Applications`, attempted two fixture cycles (20 seconds each), then a normal
Launch Services launch without fixture arguments. Both fixture cycles were blocked
before status-button/quit identity observation. AX trust is false, ScreenCapture is
preauthorized, and LocalAuthentication is frontmost. Normal `open` exited 0, but
Settings routing could not be observed. No compositor screenshot was synthesized.
`score` and `pixel_diff` are null; no visual or live-interaction pass is claimed.

Native termination was requested and accepted for PIDs **66509**, **66681**, **66843**.
Fixture cleanup had a five-second SIGKILL fallback; its exact usage was not separately
logged, so graceful Quit is not inferred. Normal launch needed no force fallback.
All three PIDs are independently absent and own no compositor windows afterward
(`capture/*-after.json`, `process-cleanup.log`). The temporary Applications bundle
was removed. Cleanup success is not proof that the production Quit action ran.

All existing cumulative edits were preserved, on the supplied worktree/branch,
without a commit. Remaining acceptance: unlocked/trusted desktop verification of
native Quit, status item disappearance, and fresh Applications launch routing.
