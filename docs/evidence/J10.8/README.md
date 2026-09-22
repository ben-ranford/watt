# G072 / J10.8 — Helper changed

Exact Figma MCP file `9DKDgUfEqidZdZQEVlQgLS`, frame `34:6183` (1000×720), alert `34:6340` (260×246 at 370,230). Retrieved design context before implementation; raw text MCP responses are saved in context.json, metadata.json, variable_defs.json and screenshot.json. reference.png is the fresh MCP screenshot; context.png is the supplied context URL. reference.sha256 verifies both. Reference inspected visually.

Implementation: App/HelperUpdatePresentation.swift uses an informational NSAlert, exact copy, Update Helper/Return and Later/Escape. macOS owns icon, semantic fonts, materials, accent, geometry and buttons; design coordinates and liquid-glass variables are evidence, not custom rendering instructions. Existing AppKit status-item bridge remains unchanged. App/WattApp.swift supplies DEBUG-only J10.8/base fixture values through existing stores/preferences. No real helper install, approval or network effects in the fixture.

Presentation IDs scope button intents; generation IDs reject late verification/update replies and protect a newer operation's busy state. Relaunch proof is required before helper mutation. Retry preserves operation receipt. Later/close invalidate the generation without changing preferences. J3.3 regression assertions now verify the shared native NSAlert.

Reproduce: `bash docs/evidence/J10.8/verify.sh`. Focused tests include J10, NativeStyling and P04; full swift test includes J3.3. Xcode Debug build/analyze/build-for-testing, Release build/analyze and Release test-build attempt are logged separately. Release binary is checked for fixture selector/symbol exclusion. Initial regression attempt used CommandLineTools rather than full Xcode and failed; the verification script explicitly selects Xcode.

## Final verification

- Focused J10 / NativeStyling / P04: **96 tests, zero failures**.
- Full `swift test`: **634 tests, 5 skipped, zero failures**. F05 expected implemented-story list now includes J10.8; the final full-tests.log replaces the earlier failing run.
- Debug build, analyze, build-for-testing: pass. Release app build/analyze: pass.
- Release build-for-testing: attempted, exit 65; production Watt module lacks `-enable-testing` for `@testable` imports. Release settings were not weakened.
- Static checks: diff whitespace, Xcode project syntax, reference checksums, native styling and Release fixture symbol/selector exclusion pass.
- Real app-owned NSAlert captured and visually inspected (`capture/native-window.png`). Screen capture is preauthorized; AX is not. Native 260×268 geometry differs from Figma 260×246 due to OS wrapping. Window-only capture does not preserve full desktop material composition.
- Status-item/compositor capture and AX-driven action verification remain unproven. Metrics are **null**, visualPass is false; no fake score, permission requests or replacement UI screenshots.

Changed implementation/tests: App/HelperUpdatePresentation.swift, App/WattApp.swift, Tests/Fixtures/{StoryFixtures,FixtureLaunchSelection}.swift, Tests/WattTests/{J108HelperUpdateTests,J33HelperUpdateTests,F05FixtureTests}.swift, Watt.xcodeproj/project.pbxproj; DESIGN.md and SCREEN-BACKLOG.md document the contract. Existing unrelated dirty work was preserved. No commit created.
