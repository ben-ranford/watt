# J8.3 — Opening Watt? again from Finder or Spotlight shows Settings

## Figma evidence

- File: `9DKDgUfEqidZdZQEVlQgLS`
- Story node: `32:4575`
- Frame: 1000 × 720
- Settings node: `32:4893`, 520 × 311, title `Watt? Settings`
- Design URL: https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=32-4575
- User-supplied and MCP-retrieved screenshots are byte-identical:
  `95284e826372536b4105a03e4749ebf28412329359c01fe9168ced544a837242`

The exact MCP context, metadata hierarchy, screenshot response, reference
manifest hash and image files are stored beside this document. The manifest
frame-export hash is recorded as supplied by the fixture metadata; the
corresponding raw export was not re-created.

## Implementation

Configured normal launch now presents the existing native Settings scene after
the first-completion coach-mark branch. Reopen events continue through the
existing AppKit/SwiftUI bridge. Shared preferences are preserved. The Debug
fixture uses the real `SettingsRootView` and native grouped Form controls for
the compact reference rows; it does not replace the system window or draw any
desktop/window chrome. The selector is compiled only for Debug.

## Verification

See `verification.json` for command-level results. Focused J8.3 tests passed;
the full package suite passed with 561 tests and 5 existing skips, and the
complete native WattTests unit target passed. The all-target native scheme was
blocked only by the separate WattUITests runner timing out while enabling
automation mode.

## Visual capture boundary

`capture.sh` launches the Debug fixture, waits for its native Settings scene,
and asks the system compositor to capture the real window. It records
`score: null` and `pixel_diff: null` when AX trust, TCC, PID ownership or
compositor enumeration is unavailable. It does not synthesize a screenshot or
claim a visual score on a failed gate. The launched process is terminated and
reaped by the capture script.
