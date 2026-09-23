# C03 live native secondary-click evidence — 2026-09-24

The running Release app at `/Users/benranford/Desktop/Watt.app` was exercised
with a real Quartz right-button event at the AX-discovered native Watt status
item (`AXMenuBarItem`, live title `7.6 W`, point `(1220,15)`). No debug anchor,
custom menu view, global menu painting, or fixture launch was used.

The resulting native AppKit menu was captured in
`live-secondary-click-2026-09-24.png`. A WindowServer listing during tracking
reported the Watt-owned menu as a native layer-101 window with bounds
`230×187pt` at `(1251,45)`, plus the app-owned native Watt? panel. The menu
contains the expected native rows and shortcuts, including Show in Menu Bar,
Open Watt?, Settings…, About Watt?, Check for Updates… and Quit Watt?.

`Check for Updates…` is dimmed in this Release interaction because production
updater composition intentionally fails closed without a trusted P04 service;
the enabled row remains covered by the existing DEBUG C03 fixture evidence.
This live run proves native status-item secondary-click/menu opening and current
menu geometry, but it does not close C03's visual-fidelity or TCC/VoiceOver
acceptance gates.
