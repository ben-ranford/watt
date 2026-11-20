# Shortcuts exercise

Manual check on a Mac. Unit tests cover the reading rules, the display-mode write, the update hand-off, and the reopen guard. Window focus still needs a real Mac.

Watt? is a menu-bar app with no Dock icon (`LSUIElement`). Each action runs in the Watt? process that is already open. Shortcuts also sends the accessory app a reopen. That reopen must not open Settings. Finder and the Dock still open Settings when you open Watt? itself.

Get Power Reading and Set Menu Bar Display stay in the background and finish with their result. Open Status Panel, Open Settings, and Check for Updates present that existing UI themselves, then return. None of them ask Shortcuts to launch a foreground copy of the app. That launch is what left the shortcut on Stop and made `shortcuts run` report `LinkDaemon.ProcessRegistry.Errors error 0`: LinkDaemon had no foreground process to register, and the hardened-runtime entitlements stay empty. Private RunningBoard entitlements are not available to this app.

## Before you start

1. Build Watt and launch it. Leave it running in the menu bar.
2. Open Shortcuts. If Watt? is missing, quit Shortcuts and launch Watt? again. The system index can lag a new build.
3. The actions read the store the app already keeps. They do not start a sampler of their own. A reading taken before the first sample is Unavailable.
4. A shortcut must finish on its own. It must not sit on Stop, and it must not leave Settings open unless the action is Open Settings. Finder’s reopen of the running app still opens Settings.

## Get Power Reading

Phrases: “Get the power reading in Watt?”, “What's the power draw in Watt?”.

1. Run Get Power Reading while the panel shows a live sample.
2. The result has system draw, charger watts, battery percent, and battery state. A measured 0 W, such as an idle system draw, stays 0 W.
3. Wait until the panel says No reading, then run the action again. The result is Unavailable. It is not 0 W. An unplugged charger is Unavailable for charger watts, not 0 W.

## Open the panel and Settings

Phrases: “Open Watt?”, “Show the Watt? panel”, “Open Watt? settings”.

1. Run Open Status Panel. The power panel opens in front of other apps.
2. Run Open Settings. Settings comes forward the same way.
3. Confirm Watt? still has no Dock icon.

## Menu bar display

Phrases: “Set Watt? menu bar to”, “Show … in Watt?”.

1. Pick System Draw, Battery Delta, Charger Input, Per Component, or Icon Only.
2. The menu-bar item changes to that mode. These are the same choices as Settings → Show.

## Check for Updates

Phrase: “Check for Watt? updates”.

1. Run Check for Updates.
2. The existing Software Update window opens and the check uses the signed-manifest updater. Signature and hash verification are unchanged.
3. A build without update configuration says updates aren’t configured. It does not download or install.
4. None of these actions install, update, or remove the privileged helper.

## Command line

`shortcuts run` should print the action's result. The app does not ask Shortcuts to launch a second, foreground Watt?. If the Shortcuts app finishes the action and `shortcuts run` still reports `LinkDaemon.ProcessRegistry.Errors error 0`, LinkDaemon has not registered this accessory process. That registration is not something the app can force with its Info.plist or with the empty hardened-runtime entitlements.
