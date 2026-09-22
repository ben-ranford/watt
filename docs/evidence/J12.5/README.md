# G077 / J12.5 — Reconnected

Exact source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, frame `35:5926`.
`figma-context.json`, `figma-metadata.json`, `figma-screenshot.json`,
`figma-variables.json`, and `figma-footnote.json` retain the MCP responses.
`reference.png` is the exact supplied asset; `reference.sha256` verifies its bytes.
`mcp-screenshot.png` retains the embedded context screenshot. No reference edits.

## Implementation
- Existing native SettingsRootView / Form / Section / LabeledContent / bordered Button.
  Exact connected subtitle, On value, Remove… and reconnect footnote. Native `.footnote`
  maps the supplied SF Pro 10/13 token; no asserted measured native typography.
- Existing MenuBarExtra/status-item bridge, charging Delta `+42.1 W`, 540-point
  fixture content-width request. No custom window, titlebar, status item or desktop.
- Generation/presentation-scoped reconnect consumes consent before suspension. A
  durable operation receipt precedes P05/P02 reconciliation. Only connected success
  can persist the All Set preference transition, publish helper state and route
  `.onboarding`. Receipt and undelivered continuation survive restart; retries do
  not repeat an acknowledged helper effect. Closed/in-flight/stale intent tests apply.
- Root cause of the original success-test failure: `helperOn` required a Settings-owned
  service even after an explicitly verified P05 reconnect. It now accepts the verified
  connected state without that extra ownership condition, while retaining the live
  HelperLifecycleAdapter disconnect guard. No stored preference alone authorizes a
  connection; subsequent reconciliation can withdraw it. Removal clears the reconnect
  notice. The original success assertion is retained without adding a fake Settings
  service to make it pass. `reconnect-regression-before.log` records the failing test.
- DEBUG-only `J12.5/base` uses in-memory services; it does not install, reconnect or
  remove an actual privileged helper. The fixture preserves All Set state while
  requesting the native Settings scene for the supplied frame. Live installer wiring
  is not claimed verified. Registry, F05 expected list and Xcode membership updated.

## Reproduce and evidence
Run `bash docs/evidence/J12.5/verify.sh` with Xcode installed. It records focused/full
Swift tests, Debug build/analyze/build-for-testing, Release build/analyze and a
Release build-for-testing attempt, native capture and static checks in `.log`/`.exit`.
`verification.json` is the final result summary. Initial command-line-tools SDK failure
is retained separately in `initial-tests.log`; subsequent runs use Xcode DEVELOPER_DIR.
No standalone lint configuration exists for this change; compiler/analyzer, project
plutil, checksum, Release binary fixture isolation and `git diff --check` are checked.

## Visual limitations
The exact reference was inspected. Its visible section header says “Helper”, while
its structural node and the supplied requirement specify Component Readings; this
implementation preserves the existing Component Readings section as requested.
Native capture uses a bounded ten-second launch and PID-owned window enumeration.
No native Settings window was visible during the capture attempt. Screen Recording
preflight was true, Accessibility trust false; no TCC prompt or permission change was
attempted. Native image inspection and geometry/font/button comparison are therefore
blocked. Reference dimensions 1000×720, window 540×206 at (230,267) are design values,
not measured native results. Native metrics, score and pixel difference remain null;
visualPass is false. See `visual-review.json` and `capture/window.json`.

Release app build/analyze and fixture isolation are independent of the Release test
bundle: build-for-testing is attempted honestly and currently fails on incompatible
Watt test-module resolution. Debug test-build and executed Swift tests provide test
coverage; no Release tests are claimed run. Existing compiler concurrency warnings
are retained in logs. No commit was made.
