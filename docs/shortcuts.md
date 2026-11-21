# Shortcuts exercise

Manual check on a Mac. Unit tests cover the reading rules, the display-mode write, the update hand-off, the reopen guard, and the rule that an App Intents launch does not replace the running process. Window focus and `shortcuts run` still need a real Mac.

Watt? is a menu-bar app with no Dock icon (`LSUIElement`). Each action runs against the Watt? process that is already open. A second process that linkd starts for the action must not quit that process and must not post the reopen that opens Settings. Finder and the Dock still open Settings when you open Watt? itself.

Get Power Reading and Set Menu Bar Display stay in the background and finish with their result. Open Status Panel, Open Settings, and Check for Updates present that existing UI themselves, then return. None of them ask Shortcuts to launch a foreground copy of the app. None of them start a sampler. A reading taken before the first sample is Unavailable.

Same-repo CI signs the Release app with Developer ID for team `GUT4TJFVQ2` and notarises it. LinkDaemon routes an App Intent with that Team ID. An ad-hoc build (`TeamIdentifier` not set) can list the actions and still never call `perform()`. Use the stapled `Watt-app-pr` artifact from the green macOS job, not a local ad-hoc build. The launch log line records the team id, the ad-hoc flag, and the cdhash.

## Mac test procedure

Use the machine that can run the app. The last check was macOS 27.2.1 on a MacBook Air M3. Install the signed artifact at `/Applications/Watt.app`.

1. Quit every running Watt?, including one left over from Homebrew. Confirm none remain:

   ```bash
   pgrep -lf 'Watt.app/Contents/MacOS/Watt' || echo "no Watt process"
   ```

2. Install the `Watt-app-pr` artifact from the green macOS job on this pull request over `/Applications/Watt.app`. Launch that copy once from Finder and leave it in the menu bar. Record its pid:

   ```bash
   pgrep -lf 'Watt.app/Contents/MacOS/Watt'
   ```

   There must be one pid. That pid is the one every action below has to keep.

3. In a second Terminal, start the intent log and leave it running for the whole check:

   ```bash
   log stream --level debug --style compact --predicate 'subsystem == "io.github.ben-ranford.watt" AND category == "intents"'
   ```

4. Confirm the signature before running an action. `TeamIdentifier` must be `GUT4TJFVQ2`, the authority must be Developer ID, and the cdhash of the running process must match `/Applications/Watt.app`. The launch log should show `team=GUT4TJFVQ2` and `adhoc=false`. An empty TeamIdentifier means this is not the signed artifact, and the five actions will not finish:

   ```bash
   codesign -dv --verbose=4 /Applications/Watt.app 2>&1 | egrep 'Identifier=|TeamIdentifier=|Signature|CDHash='
   ```

5. In Shortcuts, search the Action Library for “Watt?”. These five actions must be listed: Get Power Reading, Open Status Panel, Open Settings, Set Menu Bar Display, and Check for Updates. Make a temporary shortcut for each one, run it, then delete the shortcuts. Run each of these and then the same action with `shortcuts run` on the shortcut name:

   ```bash
   shortcuts run "Watt Get Power Reading"
   shortcuts run "Watt Open Status Panel"
   shortcuts run "Watt Open Settings"
   shortcuts run "Watt Set Menu Bar Display"
   shortcuts run "Watt Check for Updates"
   ```

   Set Menu Bar Display’s Display parameter is Charger Input before that shortcut is run.

6. After every action, including the ones you stop yourself, run `pgrep` again. The original pid is still the only Watt? pid. The action returns on its own. It does not sit on Stop, and the Shortcuts editor does not show `LinkDaemon.ProcessRegistry.Errors error 0`.

Pass looks like this:

- **Get Power Reading.** No Settings window. The result is one plain sentence, with no dialog: system draw, charger watts, battery percent, and battery state. A measured 0 W stays 0 W. When the panel title is Not charging and the detail is Power source: AC, the battery state is `Not charging`, not `Unknown`. `shortcuts run` prints that sentence and exits. The log contains `reading via=local` or `reading via=keeper` and the same summary. If the panel says No reading, the result is Unavailable, not 0 W.
- **Open Status Panel.** The power panel opens from the menu-bar button and stays open, including when Shortcuts is hidden. The log contains `status panel shown=true` and `open via=local destination=statusPanel` or `open via=keeper destination=statusPanel`. Settings does not open.
- **Open Settings.** Settings comes forward. The shortcut still finishes.
- **Set Menu Bar Display.** The menu-bar item changes to charger input. Settings does not open. The stored mode is the Settings value `Charger`, not the Shortcuts label `Charger Input`:

  ```bash
  defaults export io.github.ben-ranford.watt - | plutil -extract preferences.v1 raw -o - -
  ```

- **Check for Updates.** The Software Update window opens and comes forward, the same window as Check for Updates… in the menu. Checking finishes on its own: You’re up to date, the available-update screen, or the couldn’t-check alert. It does not stay on Checking. `shortcuts run` prints the status sentence and exits. A build without update configuration says updates aren’t configured. It does not download or install.
- **Finder reopen.** In Finder, open the already-running `/Applications/Watt.app`. Settings opens on the same pid. The log may say `decision=waitForIntent` when the reopen has no sender and Finder is not the frontmost app. Settings still opens once that short wait ends. It opens immediately when the sender or the frontmost app is Finder.
- **Dock icon.** Watt? is not in the Dock. `LSUIElement` stays 1.

If linkd did start a second process, the log shows `satellite pid=… leaving <original pid> running; single-instance claim skipped` and does not show `yielded to running instance` during the action. The original pid is still alive when the shortcut finishes.

Copy the intent log into the pull request if a run fails. This shows the same lines after the fact:

```bash
log show --last 10m --style compact --predicate 'subsystem == "io.github.ben-ranford.watt" AND category == "intents"'
```

## Actions

### Get Power Reading

Phrases: “Get the power reading in Watt?”, “What's the power draw in Watt?”.

1. Run Get Power Reading while the panel shows a live sample.
2. The result is one sentence with system draw, charger watts, battery percent, and battery state. There is no result dialog. A measured 0 W, such as an idle system draw, stays 0 W. Not charging on AC is `Not charging`. `shortcuts run` prints the sentence and exits. Apple’s command-line guide says `shortcuts run` pauses when a shortcut shows an alert or asks for input ([Run shortcuts from the command line](https://support.apple.com/guide/shortcuts-mac/run-shortcuts-from-the-command-line-apd455c82f02/mac)). These two actions return a string and do not show one.
3. Wait until the panel says No reading, then run the action again. The result is Unavailable. It is not 0 W. An unplugged charger is Unavailable for charger watts, not 0 W.

### Open the panel and Settings

Phrases: “Open Watt?”, “Show the Watt? panel”, “Open Watt? settings”.

1. Run Open Status Panel. The power panel opens in front of other apps.
2. Run Open Settings. Settings comes forward the same way.
3. Confirm Watt? still has no Dock icon.

### Menu bar display

Phrases: “Set Watt? menu bar to”, “Show … in Watt?”.

1. Pick System Draw, Battery Delta, Charger Input, Per Component, or Icon Only.
2. The menu-bar item changes to that mode. These are the same choices as Settings → Show.

### Check for Updates

Phrase: “Check for Watt? updates”.

1. Run Check for Updates.
2. The existing Software Update window opens and the check uses the signed-manifest updater. Signature and hash verification are unchanged.
3. A build without update configuration says updates aren’t configured. It does not download or install.
4. None of these actions install, update, or remove the privileged helper.
