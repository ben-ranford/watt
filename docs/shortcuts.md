# Shortcuts exercise

Manual check of a Developer ID build. Unit tests cover the reading rules, the display-mode write, the reopen guard, the dependency registration, and the rule that an App Intents launch does not replace the running process. Window focus and `shortcuts run` still need that signed build.

Watt? is a menu-bar app with no Dock icon (`LSUIElement`). Each action runs against the Watt? process that is already open. A second process that linkd starts for the action must not quit that process and must not post the reopen that opens Settings. Finder and the Dock still open Settings when you open Watt? itself.

Set Menu Bar Display stays in the background and finishes with its result. Get Power Reading stays in the background and returns its sentence. Open Status Panel and Open Settings present that existing UI themselves, then return. None of them ask Shortcuts to launch a foreground copy of the app. None of them start a sampler, and none of them start an update check. A reading taken before the first sample is Unavailable.

`.github/workflows/ci.yml` signs the Release app with Developer ID for team `GUT4TJFVQ2` and notarises it on a same-repo pull request, when the Developer ID secrets are present. That job uploads the stapled app as `Watt-app-pr`. A fork pull request skips the keychain and uploads an ad-hoc build instead. LinkDaemon routes an App Intent only when `TeamIdentifier` is set. An ad-hoc build (`TeamIdentifier` not set, or `Signature=adhoc`) can list the actions and still never call `perform()`. Do not use a local ad-hoc build for this check. The launch log line records the team id, the ad-hoc flag, and the cdhash.

## Known limitation

`shortcuts run "Watt Get Power Reading"` from Terminal may not exit even though the reading is returned. The sentence in the output is the result. Stop the command if it stays open. The Shortcuts app still shows the same sentence. This does not mean the action failed, and it does not apply to the other three actions.

## Signed build check

Use the `Watt-app-pr` zip from the green macOS job on a same-repo pull request. Confirm the zip itself before it replaces the installed app.

1. Download `Watt-app-pr` and expand it somewhere other than `/Applications`:

   ```bash
   ditto -x -k Watt.app.zip /tmp/watt-pr-check
   codesign -dv --verbose=4 /tmp/watt-pr-check/Watt.app 2>&1 | egrep 'Identifier=|TeamIdentifier=|Signature|Authority=|CDHash='
   /usr/sbin/spctl -a -vvv -t exec /tmp/watt-pr-check/Watt.app
   ```

   Pass for this zip:

   - `TeamIdentifier=GUT4TJFVQ2`
   - `Authority=Developer ID Application:`
   - the signature flags do not include `adhoc`
   - `spctl` reports `source=Notarized Developer ID`

   Stop if `Signature=adhoc` or `TeamIdentifier` is not set. That zip is the fork artifact, or the keychain import did not run. The four actions will be listed and will not call `perform()`.

2. Quit every running Watt?, including one left over from Homebrew. Confirm none remain:

   ```bash
   pgrep -lf 'Watt.app/Contents/MacOS/Watt' || echo "no Watt process"
   ```

3. Replace `/Applications/Watt.app` with the bundle you just checked. Register that bundle, then launch it once from Finder and leave it in the menu bar:

   ```bash
   rm -rf /Applications/Watt.app
   ditto /tmp/watt-pr-check/Watt.app /Applications/Watt.app
   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Watt.app
   open /Applications/Watt.app
   pgrep -lf 'Watt.app/Contents/MacOS/Watt'
   ```

   There must be one pid. That pid is the one every action below has to keep.

4. In a second Terminal, start the intent log and leave it running for the whole check:

   ```bash
   log stream --level debug --style compact --predicate 'subsystem == "io.github.ben-ranford.watt" AND category == "intents"'
   ```

5. Confirm the running app is the bundle you checked. The launch log must show `team=GUT4TJFVQ2` and `adhoc=false`, and this cdhash must match the zip:

   ```bash
   codesign -dv --verbose=4 /Applications/Watt.app 2>&1 | egrep 'Identifier=|TeamIdentifier=|Signature|Authority=|CDHash='
   ```

   An empty TeamIdentifier means the running process is not the signed artifact. Quit it and go back to step 1. Do not run the four actions on that process.

6. In Shortcuts, search the Action Library for “Watt?”. These four actions must be listed: Get Power Reading, Open Status Panel, Open Settings, and Set Menu Bar Display. There is no update action. Make a temporary shortcut for each one, run it, then delete the shortcuts. Run each of these and then the same action with `shortcuts run` on the shortcut name:

   ```bash
   shortcuts run "Watt Get Power Reading"
   shortcuts run "Watt Open Status Panel"
   shortcuts run "Watt Open Settings"
   shortcuts run "Watt Set Menu Bar Display"
   ```

   Set Menu Bar Display’s Display parameter is Charger Input before that shortcut is run. Get Power Reading may print its sentence and then stay running. That is the known limitation above. The other three commands should exit.

7. After every action, including the ones you stop yourself, run `pgrep` again. The original pid is still the only Watt? pid. The intent log contains `perform begin` for that action. Open Status Panel, Open Settings, and Set Menu Bar Display return on their own. They do not sit on Stop, and the Shortcuts editor does not show `LinkDaemon.ProcessRegistry.Errors error 0`. A log that only has `reopen` and never `perform begin` means LinkDaemon did not deliver the action.

Pass looks like this:

- **Get Power Reading.** No Settings window. The result is one plain sentence, with no dialog: system draw, charger watts, battery percent, and battery state. A measured 0 W stays 0 W. When the panel title is Not charging and the detail is Power source: AC, the battery state is `Not charging`, not `Unknown`. The log contains `reading via=local` or `reading via=keeper` and the same summary. If the panel says No reading, the result is Unavailable, not 0 W. `shortcuts run` may not exit after it prints that sentence. The printed sentence is still the pass.
- **Open Status Panel.** The power panel opens from the menu-bar button and stays open, including when Shortcuts is hidden. The log contains `status panel shown=true` and `open via=local destination=statusPanel` or `open via=keeper destination=statusPanel`. Settings does not open.
- **Open Settings.** Settings comes forward. The shortcut still finishes.
- **Set Menu Bar Display.** The menu-bar item changes to charger input. Settings does not open. The stored mode is the Settings value `Charger`, not the Shortcuts label `Charger Input`:

  ```bash
  defaults export io.github.ben-ranford.watt - | plutil -extract preferences.v1 raw -o - -
  ```

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
2. The result is one sentence with system draw, charger watts, battery percent, and battery state. There is no result dialog. A measured 0 W, such as an idle system draw, stays 0 W. Not charging on AC is `Not charging`. In Shortcuts, the sentence is the result. From Terminal, `shortcuts run "Watt Get Power Reading"` may not exit even though that sentence was returned. Apple’s command-line guide says `shortcuts run` pauses when a shortcut shows an alert or asks for input ([Run shortcuts from the command line](https://support.apple.com/guide/shortcuts-mac/run-shortcuts-from-the-command-line-apd455c82f02/mac)). This action returns a string and does not show one, and the command can still stay open.
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

None of these actions install, update, or remove the privileged helper.
