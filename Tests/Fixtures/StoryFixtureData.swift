#if DEBUG || SWIFT_PACKAGE
import Foundation

// Pinned scenario catalogue for debug fixtures. No runtime file lookup.
enum StoryFixtureData {
    static let stories: [StoryFixture] = {
        let json = #"""
[
  {
    "id": "C01",
    "node": "C01",
    "frame": "1 · Status Panel — Charging",
    "state": "Panel: charging, +42.1 W, 64%, charger/system/battery rows and CPU/GPU/Display/Other rows",
    "navigation": "Menu-bar primary click → open panel; Settings… → Settings scene; Quit Watt? → terminate",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"node\":\"C01\",\"story\":\"C01\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Panel: charging, +42.1 W, 64%, charger/system/battery rows and CPU/GPU/Display/Other rows. Assert these exact displayed values, availability, controls and state changes against fixture `C01`; apply D1–D7."
  },
  {
    "id": "C02",
    "node": "C02",
    "frame": "2 · Status Panel — On Battery (Light)",
    "state": "Panel: on-battery, −18.4 W, remaining-time subtitle; light appearance",
    "navigation": "Menu-bar primary click in light mode → panel; rows remain the same semantic surface",
    "expectedScene": "panel",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C02\",\"story\":\"C02\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Panel: on-battery, −18.4 W, remaining-time subtitle; light appearance. Assert these exact displayed values, availability, controls and state changes against fixture `C02`; apply D1–D7."
  },
  {
    "id": "C03",
    "node": "C03",
    "frame": "3 · Secondary-Click Menu (Dark)",
    "state": "Dark status item context menu; action/submenu items, hover+keyboard, selected submenu",
    "navigation": "Status-item secondary click → menu; Open Watt? → panel; Settings… → settings; updates → update flow; Quit → terminate",
    "expectedScene": "contextMenu",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C03\",\"story\":\"C03\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark status item context menu; action/submenu items, hover+keyboard, selected submenu. Assert these exact displayed values, availability, controls and state changes against fixture `C03`; apply D1–D7."
  },
  {
    "id": "C04.1",
    "node": "C04.1",
    "frame": "Delta · charging",
    "state": "Status item: charging delta",
    "navigation": "Menu-bar status item from charging telemetry → C01 panel",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C04.1\",\"story\":\"C04.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: charging delta. Assert these exact displayed values, availability, controls and state changes against fixture `C04.1`; apply D1–D7."
  },
  {
    "id": "C04.2",
    "node": "C04.2",
    "frame": "Delta · on battery",
    "state": "Status item: negative battery delta",
    "navigation": "Menu-bar status item from on-battery telemetry → C02 panel",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C04.2\",\"story\":\"C04.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: negative battery delta. Assert these exact displayed values, availability, controls and state changes against fixture `C04.2`; apply D1–D7."
  },
  {
    "id": "C04.3",
    "node": "C04.3",
    "frame": "Delta · charged, on adapter",
    "state": "Status item: full/charged adapter state",
    "navigation": "Menu-bar status item → charged panel state",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C04.3\",\"story\":\"C04.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: full/charged adapter state. Assert these exact displayed values, availability, controls and state changes against fixture `C04.3`; apply D1–D7."
  },
  {
    "id": "C04.4",
    "node": "C04.4",
    "frame": "Charger Input",
    "state": "Status item: charger input mode",
    "navigation": "Settings display mode → status item; click → panel",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C04.4\",\"story\":\"C04.4\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: charger input mode. Assert these exact displayed values, availability, controls and state changes against fixture `C04.4`; apply D1–D7."
  },
  {
    "id": "C04.5",
    "node": "C04.5",
    "frame": "Charger Input · unplugged (falls back to System Draw)",
    "state": "Unplugged charger mode falls back to system draw",
    "navigation": "Telemetry loses charger → fallback status item and panel without stale charger value",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C04.5\",\"story\":\"C04.5\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Unplugged charger mode falls back to system draw. Assert these exact displayed values, availability, controls and state changes against fixture `C04.5`; apply D1–D7."
  },
  {
    "id": "C04.6",
    "node": "C04.6",
    "frame": "System Draw (desktop Macs)",
    "state": "Status item: system draw on a Mac with no battery",
    "navigation": "Desktop/no-battery capability → system draw status item and panel",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C04.6\",\"story\":\"C04.6\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: system draw on a Mac with no battery. Assert these exact displayed values, availability, controls and state changes against fixture `C04.6`; apply D1–D7."
  },
  {
    "id": "C04.7",
    "node": "C04.7",
    "frame": "Per Component (max 2)",
    "state": "Status item: at most two component readings",
    "navigation": "Settings component selection → status item; click → component panel",
    "expectedScene": "statusItem",
    "appearance": "dark",
    "referenceJSON": "{\"node\":\"C04.7\",\"story\":\"C04.7\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: at most two component readings. Assert these exact displayed values, availability, controls and state changes against fixture `C04.7`; apply D1–D7."
  },
  {
    "id": "C04.8",
    "node": "C04.8",
    "frame": "Icon Only (notch / crowded menu bar)",
    "state": "Status item icon-only fallback",
    "navigation": "Crowded/notch preference → icon-only status item; panel remains discoverable",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C04.8\",\"story\":\"C04.8\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item icon-only fallback. Assert these exact displayed values, availability, controls and state changes against fixture `C04.8`; apply D1–D7."
  },
  {
    "id": "C04.9",
    "node": "C04.9",
    "frame": "No reading yet / sensor unavailable",
    "state": "Status item: no reading/sensor unavailable",
    "navigation": "Telemetry unavailable → no-reading status item; recovery → normal status item",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C04.9\",\"story\":\"C04.9\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: no reading/sensor unavailable. Assert these exact displayed values, availability, controls and state changes against fixture `C04.9`; apply D1–D7."
  },
  {
    "id": "C04.10",
    "node": "C04.10",
    "frame": "Panel open (selected)",
    "state": "Selected status item while panel is open",
    "navigation": "Primary click opens selected state; close returns to unselected status item",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C04.10\",\"story\":\"C04.10\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Selected status item while panel is open. Assert these exact displayed values, availability, controls and state changes against fixture `C04.10`; apply D1–D7."
  },
  {
    "id": "C04.11",
    "node": "C04.11",
    "frame": "Light menu bar · charging",
    "state": "Light menu-bar contrast variant while charging",
    "navigation": "System appearance/light menu bar → readable status item",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C04.11\",\"story\":\"C04.11\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Light menu-bar contrast variant while charging. Assert these exact displayed values, availability, controls and state changes against fixture `C04.11`; apply D1–D7."
  },
  {
    "id": "C04.12",
    "node": "C04.12",
    "frame": "Light menu bar · on battery",
    "state": "Light menu-bar contrast variant while on battery",
    "navigation": "System appearance/light menu bar + battery → readable status item",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C04.12\",\"story\":\"C04.12\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Light menu-bar contrast variant while on battery. Assert these exact displayed values, availability, controls and state changes against fixture `C04.12`; apply D1–D7."
  },
  {
    "id": "C05",
    "node": "C05",
    "frame": "5 · Settings Window (Light)",
    "state": "Full grouped Settings window: Menu Bar, Readings, Component Readings, Notifications, General",
    "navigation": "Settings… from context/panel or app launch → settings; changes update shared preferences and status label",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"node\":\"C05\",\"story\":\"C05\"}",
    "variants": [
      "base",
      "helper-off",
      "helper-pending",
      "helper-on",
      "helper-update-required",
      "login-denied",
      "notification-denied"
    ],
    "acceptance": "Full grouped Settings window: Menu Bar, Readings, Component Readings, Notifications, General. Assert these exact displayed values, availability, controls and state changes against fixture `C05`; apply D1–D7."
  },
  {
    "id": "J1.1",
    "node": "J1.1",
    "frame": "1.1 Welcome",
    "state": "First-launch welcome; app icon placeholder; Continue",
    "navigation": "First launch → Continue to J1.2; close → J5.1 defaults/resume semantics",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J1.1\",\"story\":\"J1.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "First-launch welcome; app icon placeholder; Continue. Assert these exact displayed values, availability, controls and state changes against fixture `J1.1`; apply D1–D7."
  },
  {
    "id": "J1.2",
    "node": "J1.2",
    "frame": "1.2 Choose a menu bar reading",
    "state": "Radio picker: Delta selected; Charger, Draw, Components descriptions",
    "navigation": "J1.1 Continue → this; Back → J1.1; Continue → J1.3; no-battery branch → J4.2",
    "expectedScene": "onboarding",
    "appearance": "light",
    "referenceJSON": "{\"node\":\"J1.2\",\"story\":\"J1.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Radio picker: Delta selected; Charger, Draw, Components descriptions. Assert these exact displayed values, availability, controls and state changes against fixture `J1.2`; apply D1–D7."
  },
  {
    "id": "J1.3",
    "node": "J1.3",
    "frame": "1.3 Offer component readings",
    "state": "Helper facts: what it reads, network access, remove it; Not Now and Turn On…",
    "navigation": "J1.2 Continue → this; Not Now → J1.6; Turn On… → J1.4",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J1.3\",\"story\":\"J1.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Helper facts: what it reads, network access, remove it; Not Now and Turn On…. Assert these exact displayed values, availability, controls and state changes against fixture `J1.3`; apply D1–D7."
  },
  {
    "id": "J1.4",
    "node": "J1.4",
    "frame": "1.4 Waiting for approval (system notification)",
    "state": "Approval pending window + indeterminate spinner + system notification",
    "navigation": "J1.3 Enable → this; Open System Settings → external approval; Cancel/timeout → J3.1",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J1.4\",\"story\":\"J1.4\"}",
    "variants": [
      "base",
      "cancel-one-approve-other-onboarding",
      "cancel-one-approve-other-settings",
      "cancel-both-then-approve-onboarding",
      "cancel-both-then-approve-settings",
      "retry-rejoin-active-onboarding",
      "retry-rejoin-active-settings",
      "retry-after-both-cancel-onboarding",
      "retry-after-both-cancel-settings",
      "continue-without-other-waits-onboarding",
      "continue-without-other-waits-settings",
      "continue-without-no-interest-onboarding",
      "continue-without-no-interest-settings",
      "close-and-late-callbacks-onboarding",
      "close-and-late-callbacks-settings"
    ],
    "acceptance": "Approval pending window + indeterminate spinner + system notification. Assert these exact displayed values, availability, controls and state changes against fixture `J1.4`; apply D1–D7."
  },
  {
    "id": "J1.5",
    "node": "J1.5",
    "frame": "1.5 Component readings on",
    "state": "Green success, live CPU/GPU/display preview",
    "navigation": "Approval success → this; Continue → J1.6",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J1.5\",\"story\":\"J1.5\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Green success, live CPU/GPU/display preview. Assert these exact displayed values, availability, controls and state changes against fixture `J1.5`; apply D1–D7."
  },
  {
    "id": "J1.6",
    "node": "J1.6",
    "frame": "1.6 All set",
    "state": "All-set confirmation + Open at login switch",
    "navigation": "J1.5 Continue or reconnect → this; Done → J1.7/status item",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J1.6\",\"story\":\"J1.6\"}",
    "variants": [
      "base"
    ],
    "acceptance": "All-set confirmation + Open at login switch. Assert these exact displayed values, availability, controls and state changes against fixture `J1.6`; apply D1–D7."
  },
  {
    "id": "J1.7",
    "node": "J1.7",
    "frame": "1.7 First run — where Watt? lives",
    "state": "Coach mark/popover anchored to status item",
    "navigation": "J1.6 Done → coach mark; Got It → J1.8",
    "expectedScene": "coachMark",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J1.7\",\"story\":\"J1.7\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Coach mark/popover anchored to status item. Assert these exact displayed values, availability, controls and state changes against fixture `J1.7`; apply D1–D7."
  },
  {
    "id": "J1.8",
    "node": "J1.8",
    "frame": "1.8 First open — live panel",
    "state": "First live panel opened from status item",
    "navigation": "J1.7 Got It or click status item → C01/C02 according to reading",
    "expectedScene": "panel",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J1.8\",\"story\":\"J1.8\"}",
    "variants": [
      "base"
    ],
    "acceptance": "First live panel opened from status item. Assert these exact displayed values, availability, controls and state changes against fixture `J1.8`; apply D1–D7."
  },
  {
    "id": "J2.1",
    "node": "J2.1",
    "frame": "2.1 Per Component unavailable in menu",
    "state": "Context menu with disabled Per Component and Turn On Component Readings…",
    "navigation": "Secondary click → menu; enable action → J2.3/settings",
    "expectedScene": "contextMenu",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J2.1\",\"story\":\"J2.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Context menu with disabled Per Component and Turn On Component Readings…. Assert these exact displayed values, availability, controls and state changes against fixture `J2.1`; apply D1–D7."
  },
  {
    "id": "J2.2",
    "node": "J2.2",
    "frame": "2.2 Panel — component readings off",
    "state": "Panel with component section off and setup action",
    "navigation": "J2.1 Open Watt? → panel; setup action → J2.3",
    "expectedScene": "panel",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J2.2\",\"story\":\"J2.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Panel with component section off and setup action. Assert these exact displayed values, availability, controls and state changes against fixture `J2.2`; apply D1–D7."
  },
  {
    "id": "J2.3",
    "node": "J2.3",
    "frame": "2.3 Settings — turn on (excerpt)",
    "state": "Settings excerpt showing Component Readings status/helper controls",
    "navigation": "J2.2 or context action → settings; enable → J2.4",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J2.3\",\"story\":\"J2.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Settings excerpt showing Component Readings status/helper controls. Assert these exact displayed values, availability, controls and state changes against fixture `J2.3`; apply D1–D7."
  },
  {
    "id": "J2.4",
    "node": "J2.4",
    "frame": "2.4 Waiting for approval (from Settings)",
    "state": "Approval notification launched from Settings",
    "navigation": "J2.3 enable → pending; approval success → J2.5; cancellation → J3.1",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J2.4\",\"story\":\"J2.4\"}",
    "variants": [
      "base",
      "cancel-one-approve-other-onboarding",
      "cancel-one-approve-other-settings",
      "cancel-both-then-approve-onboarding",
      "cancel-both-then-approve-settings",
      "retry-rejoin-active-onboarding",
      "retry-rejoin-active-settings",
      "retry-after-both-cancel-onboarding",
      "retry-after-both-cancel-settings",
      "continue-without-other-waits-onboarding",
      "continue-without-other-waits-settings",
      "continue-without-no-interest-onboarding",
      "continue-without-no-interest-settings",
      "close-and-late-callbacks-onboarding",
      "close-and-late-callbacks-settings"
    ],
    "acceptance": "Approval notification launched from Settings. Assert these exact displayed values, availability, controls and state changes against fixture `J2.4`; apply D1–D7."
  },
  {
    "id": "J2.5",
    "node": "J2.5",
    "frame": "2.5 Turned on — Per Component available",
    "state": "Settings/panel after helper is enabled; Per Component available",
    "navigation": "J2.4 success → settings/panel; select mode → C04.7",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J2.5\",\"story\":\"J2.5\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Injected authenticated helper only; Show=Components; Components=CPU, GPU; Two fit.; Status=On; Remove…; CPU 9.8 · GPU 4.1 W. Removal, disabled readings, disconnect and revoked approval fail closed. Visual/live AX/system approval remain unverified. Apply D1–D7."
  },
  {
    "id": "J3.1",
    "node": "J3.1",
    "frame": "3.1 Approval not given (timed out or cancelled)",
    "state": "Approval failure with retry/continue-without path",
    "navigation": "J1.4/J2.4 cancellation or timeout → this; retry → approval; continue → panel without helper",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J3.1\",\"story\":\"J3.1\"}",
    "variants": [
      "base",
      "timeout",
      "cancelled",
      "cancel-one-approve-other-onboarding",
      "cancel-one-approve-other-settings",
      "cancel-both-then-approve-onboarding",
      "cancel-both-then-approve-settings",
      "retry-rejoin-active-onboarding",
      "retry-rejoin-active-settings",
      "retry-after-both-cancel-onboarding",
      "retry-after-both-cancel-settings",
      "continue-without-other-waits-onboarding",
      "continue-without-other-waits-settings",
      "continue-without-no-interest-onboarding",
      "continue-without-no-interest-settings",
      "close-and-late-callbacks-onboarding",
      "close-and-late-callbacks-settings"
    ],
    "acceptance": "Approval failure with retry/continue-without path. Assert these exact displayed values, availability, controls and state changes against fixture `J3.1`; apply D1–D7."
  },
  {
    "id": "J3.2",
    "node": "J3.2",
    "frame": "3.2 Helper switched off later in System Settings",
    "state": "Verified helper loss: native panel, Delta fallback, Fix… → Settings",
    "navigation": "Runtime helper loss → this; re-enable → approval; dismiss → panel no component rows",
    "expectedScene": "statusPanel",
    "appearance": "dark",
    "referenceJSON": "{\"node\":\"J3.2\",\"story\":\"J3.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Injected authenticated connection then disconnect; dark native panel; +42.1 W; Charger input 65.0 W; System draw 22.9 W; Battery +42.1 W; exclamationmark.triangle.fill; Helper is off; Showing Delta until it’s back.; Fix… opens Settings. No fabricated components. Apply D1–D7."
  },
  {
    "id": "J3.3",
    "node": "J3.3",
    "frame": "3.3 Helper needs updating after app update",
    "state": "Helper update required alert and Update Helper action",
    "navigation": "Post-update check → this; Update Helper → relaunch/approval; Later → panel",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J3.3\",\"story\":\"J3.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native scene-attached alert: The helper changed; Update Helper; Later. Receipt-specific signed relaunch and helper installation/authenticated approval required. Old protocol migration unsupported. No fake OS success; live/AX/visual blocked."
  },
  {
    "id": "J4.1",
    "node": "J4.1",
    "frame": "4.1 Welcome (desktop copy)",
    "state": "First-launch welcome copy for desktop Mac/no battery",
    "navigation": "Desktop first launch → J4.2; close → J5.1",
    "expectedScene": "onboarding",
    "appearance": "dark",
    "referenceJSON": "{\"node\":\"J4.1\",\"story\":\"J4.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Explicit desktop welcome: Know your watts; Watt? sits in your menu bar and shows what your Mac draws. Nothing more. Continue uses existing persisted picker route; J4.2 capability variant remains separate. Native close/Escape, WattAppIcon asset, isolated Debug storage. Visual/live acceptance blocked."
  },
  {
    "id": "J4.2",
    "node": "J4.2",
    "frame": "4.2 Choose reading — battery options unavailable",
    "state": "Radio picker with battery choices disabled",
    "navigation": "J4.1 Continue → this; Draw/System Draw → J4.3; Back → J4.1",
    "expectedScene": "onboarding",
    "appearance": "dark",
    "referenceJSON": "{\"node\":\"J4.2\",\"story\":\"J4.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native no-battery radio picker: Draw selected (38.2 W); Components helper-gated; Delta/Charger disabled. Back persists welcome; Continue preserves existing helperOffer routing, never approval. In-memory Debug fixture. AX/live/comparable visual acceptance blocked."
  },
  {
    "id": "J4.3",
    "node": "J4.3",
    "frame": "4.3 Panel — system draw only (continues at 1.3 for components)",
    "state": "Desktop panel with system draw only",
    "navigation": "J4.2 Continue → panel; component path continues at J1.3 if offered",
    "expectedScene": "panel",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J4.3\",\"story\":\"J4.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native desktop Drawing panel: 38.2 W, Mac Studio no-battery subtitle, CPU 14.6 W, GPU 11.2 W, SSD 1.9 W, Other 10.5 W. No battery/charger rows. Settings and Quit reuse production actions. Base Debug fixture isolated; helper-off, stale and unavailable states never fabricate components. Visual/AX acceptance fail closed."
  },
  {
    "id": "J5.1",
    "node": "J5.1",
    "frame": "5.1 Welcome closed → running with defaults",
    "state": "Welcome closed; Delta defaults applied; light top-trailing coach mark; setup deferred",
    "navigation": "Close welcome → coach mark; Not Now → running with defaults; Finish Setup → J1.2 picker",
    "expectedScene": "coachMark",
    "appearance": "light",
    "referenceJSON": "{\"node\":\"J5.1\",\"story\":\"J5.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native light top-trailing CoachMarkView: Watt? is on, showing System Draw. / Setup can wait. Two steps, whenever you’re ready. / Not Now / Finish Setup. Not Now persists running/default state; Finish Setup persists picker state. Stale actions are ignored. Base Debug fixture isolated. Visual/AX acceptance fail closed."
  },
  {
    "id": "J5.2",
    "node": "J5.2",
    "frame": "5.2 Panel — finish setup prompt",
    "state": "Panel prompt to finish setup",
    "navigation": "J5.1 click status item → this; Continue… → J1.2 picker",
    "expectedScene": "panel",
    "appearance": "light",
    "referenceJSON": "{\"node\":\"J5.2\",\"story\":\"J5.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native light panel: Finish setup / 2 steps left / Continue… above Charger input 65.0 W, System draw 22.9 W, Battery +42.1 W, Settings… and Quit Watt?. Selected status item 22.9 W. Continue persists incomplete J1.2 picker; stale/repeated/failed writes do not navigate. Base Debug fixture isolated. Visual/AX acceptance fail closed."
  },
  {
    "id": "J5.3",
    "node": "J5.3",
    "frame": "5.3 Right-click — Finish Setup… (resumes at 1.2)",
    "state": "Context menu Finish Setup… resumes onboarding",
    "navigation": "J5.1 secondary click → this; Finish Setup → J1.2",
    "expectedScene": "contextMenu",
    "appearance": "light",
    "referenceJSON": "{\"node\":\"J5.3\",\"story\":\"J5.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native light NSMenu: conditional Finish Setup… first action row and separator, Show in Menu Bar submenu, separator, Open Watt?, Settings… cmd-comma, separator, About Watt?, Check for Updates…, separator, Quit Watt? cmd-Q. Finish Setup persists incomplete J1.2 picker only for a current eligible menu action; changed/completed/repeated/stale actions and failed writes do not navigate. Base Debug fixture isolated. Visual/AX acceptance fail closed."
  },
  {
    "id": "J6.1",
    "node": "J6.1",
    "frame": "6.1 Plugged in — charging",
    "state": "Dark Aqua; selected +42.1 W; 320×265 native panel; Components hidden",
    "navigation": "Status item click → native charging panel; Settings… → settings; Quit Watt? → terminate",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"node\":\"J6.1\",\"story\":\"J6.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark Aqua native MenuBarExtra window at 320×265 points, selected +42.1 W status item, Charging / +42.1 W / 64% · full in about 38 min. Native grouped Form/LabeledContent: Charger input / 96 W USB-C charger / 65.0 W; System draw / 22.9 W; Battery / +42.1 W. Hide Components; native borderless Settings… and Quit Watt? callbacks. Exact isolated J6.1/base only; unavailable values remain unavailable. Missing native compositor/AX evidence blocks visual acceptance."
  },
  {
    "id": "J6.2",
    "node": "J6.2",
    "frame": "6.2 On adapter — charging on hold",
    "state": "Dark Aqua; selected 0.0 W; Holding at 80%; 320×279 native panel; Components hidden",
    "navigation": "Verified optimised hold → native panel; Settings… → settings; Quit Watt? → terminate",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"node\":\"J6.2\",\"story\":\"J6.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark Aqua native MenuBarExtra window at 320×279 points, selected battery glyph and 0.0 W. Holding at 80% / 0.0 W / Because Optimised Battery Charging is on. Charging resumes before you usually unplug. Native grouped Form/LabeledContent: Charger input / 96 W USB-C charger / 21.4 W; System draw / 21.4 W; Battery / 0.0 W. No Components. Native borderless Settings… and Quit Watt?. Require explicit hold reason and fresh valid telemetry; unavailable/failure values fail closed. Isolated Debug J6.2/base only. Missing compositor/AX evidence blocks visual acceptance."
  },
  {
    "id": "J6.3",
    "node": "J6.3",
    "frame": "6.3 On adapter — fully charged",
    "state": "Dark Aqua; selected 0.0 W; Full; 320×265 native panel; Components hidden",
    "navigation": "Verified full telemetry → native panel; Settings… → settings; Quit Watt? → terminate",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"node\":\"J6.3\",\"story\":\"J6.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark Aqua native MenuBarExtra window at 320×265 points, selected 0.0 W status item, Full / 0.0 W / 100% · running straight off the charger. Native grouped Form/LabeledContent: Charger input / 96 W USB-C charger / 19.8 W; System draw / 19.8 W; Battery / 0.0 W. Hide Components; native borderless Settings… and Quit Watt? callbacks. Require validated fresh available full-battery and adapter telemetry; connection alone never infers full. Exact isolated J6.3/base only; unsupported notification variants fail closed. Missing native compositor/AX evidence blocks visual acceptance."
  },
  {
    "id": "J6.4",
    "node": "J6.4",
    "frame": "6.4 Charger can’t keep up (notification + panel)",
    "state": "Insufficient charger notification and panel",
    "navigation": "Charger threshold event → notification + panel; dismiss preserves reading",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"node\":\"J6.4\",\"story\":\"J6.4\"}",
    "variants": [
      "base",
      "notification-on-authorized",
      "notification-on-denied",
      "notification-off-authorized",
      "notification-off-denied"
    ],
    "acceptance": "Insufficient charger notification and panel. Assert these exact displayed values, availability, controls and state changes against fixture `J6.4`; apply D1–D7. Local variants `notification-on-authorized`, `notification-off-authorized`, `notification-on-denied`, `notification-off-denied`: for the qualifying telemetry event, only on+authorized requests delivery; off or denied suppresses delivery, denied status is visibly unavailable in Settings, and preference intent survives restart without claiming permission/delivery success. Panel/status telemetry remains correct in every variant; dismissing notification/panel does not alter readings or preferences. Verify the request/result against P03 native authorization evidence, not a fake notification success."
  },
  {
    "id": "J6.5",
    "node": "J6.5",
    "frame": "6.5 Unplugged — on battery",
    "state": "Unplugged/on-battery state",
    "navigation": "Power source change → on-battery panel/status; estimate shown when valid",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"node\":\"J6.5\",\"story\":\"J6.5\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark Aqua native MenuBarExtra window at 320×265 points, selected battery glyph and −18.4 W. On battery / −18.4 W / 64% · about 4 h 10 min left. Native grouped Form/LabeledContent: Charger input / Unplugged; System draw / 18.4 W; Battery / −18.4 W. No Components. Native borderless Settings… and Quit Watt? callbacks. Reuse generic on-battery telemetry; unavailable, invalid or stale values fail closed without fabricated estimates. Isolated Debug J6.5/base only; malformed or unsupported selectors reject. Missing compositor/AX evidence blocks visual acceptance."
  },
  {
    "id": "J7.1",
    "node": "J7.1",
    "frame": "7.1 Right-click → Show in Menu Bar",
    "state": "Context menu submenu with display modes",
    "navigation": "Secondary click → submenu; select mode → J7.2/J7.4 or C04 states",
    "expectedScene": "contextMenu",
    "appearance": "light",
    "referenceJSON": "{\"node\":\"J7.1\",\"story\":\"J7.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native light AppKit status-item context menu and Show in Menu Bar submenu: Delta checked, Components natively highlighted. Frozen +42.1 W sampleCharging; completed onboarding; components/helper on; isolated Debug J7.1/base only. Shared preference mutations and AppRouter callbacks retain Finish Setup and helper-unavailable semantics. No custom menu chrome. Visual acceptance requires live PID-owned compositor/AX evidence."
  },
  {
    "id": "J7.2",
    "node": "J7.2",
    "frame": "7.2 Result — Per Component in menu bar",
    "state": "Compact result state with per-component menu label",
    "navigation": "J7.1 select Per Component → status item; click → component panel",
    "expectedScene": "statusItem",
    "appearance": "light",
    "referenceJSON": "{\"node\":\"J7.2\",\"story\":\"J7.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native Light status item: CPU 9.8 · GPU 4.1 W, no symbol. Shared MenuBarStatusLabel/PowerReading/PreferencesStore ordering and compact units. Isolated Debug J7.2/base only, frozen samplePerComponent and in-memory preferences, completed livePanel onboarding. Unavailable/stale/invalid data fails closed; max-two selection preserves order. Native macOS owns chrome, typography, spacing and placement. Visual acceptance requires live PID-owned compositor/AX capture."
  },
  {
    "id": "J7.3",
    "node": "J7.3",
    "frame": "7.3 Settings — choose components (max 2)",
    "state": "Settings component picker with max-two validation",
    "navigation": "J7.1 Settings → this; select up to two; save updates status item",
    "expectedScene": "settings",
    "appearance": "light",
    "referenceJSON": "{\"node\":\"J7.3\",\"story\":\"J7.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native Settings Form/LabeledContent and NSPopUpButton/NSMenu: Show Components; Two fit. More crowd the menu bar.; CPU, GPU checked; Display, SSD, Other disabled by available identity; Precision 42.1 W. Shared ordered max-two persisted selection; stale/unavailable action revalidation. Isolated DEBUG J7.3/base through native Settings route. Live PID/AX/compositor visual acceptance required."
  },
  {
    "id": "J7.4",
    "node": "J7.4",
    "frame": "7.4 Crowded menu bar — Icon Only",
    "state": "Compact icon-only status result",
    "navigation": "Crowded layout → icon-only fallback; click still opens panel",
    "expectedScene": "statusItem",
    "appearance": "light",
    "referenceJSON": "{\"node\":\"J7.4\",\"story\":\"J7.4\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native unselected Light battery.100percent.bolt template SF Symbol without visible text. Shared Icon Only preference and truthful accessible reading; J7.1 context routing preserved. Isolated DEBUG J7.4/base. Visual acceptance requires live PID-owned compositor/AX proof."
  },
  {
    "id": "J8.1",
    "node": "J8.1",
    "frame": "8.1 No reading (e.g. just after wake)",
    "state": "Panel/status item no-reading state",
    "navigation": "Wake/sensor gap → no-reading state; no false alert; recovery → J8.2",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"node\":\"J8.1\",\"story\":\"J8.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark native MenuBarExtra: No reading / − − W / Usually right after wake. Watt? tries again every few seconds. Native Try now row, bordered Try Again, borderless Settings… and Quit Watt?. Selected bolt.fill and − − W status. Shared fail-closed reading state and refresh path; isolated DEBUG J8.1/base only. Visual acceptance requires PID/AX/compositor proof."
  },
  {
    "id": "J8.2",
    "node": "J8.2",
    "frame": "8.2 Readings resume automatically (no alert)",
    "state": "Recovered compact state with no alert",
    "navigation": "Telemetry resumes → normal panel/status; preserve selected mode",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J8.2\",\"story\":\"J8.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Recovered compact state with no alert. Assert these exact displayed values, availability, controls and state changes against fixture `J8.2`; apply D1–D7."
  },
  {
    "id": "J8.3",
    "node": "J8.3",
    "frame": "8.3 Opening Watt? again from Finder or Spotlight shows Settings",
    "state": "App relaunch/open routes to Settings",
    "navigation": "Finder/Spotlight launch → settings scene when already configured",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J8.3\",\"story\":\"J8.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "App relaunch/open routes to Settings. Assert these exact displayed values, availability, controls and state changes against fixture `J8.3`; apply D1–D7."
  },
  {
    "id": "J9.1",
    "node": "J9.1",
    "frame": "9.1 Settings → Remove… (confirm)",
    "state": "Settings remove-helper confirmation",
    "navigation": "Settings Remove… → confirmation; Cancel returns; Remove → J9.2",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J9.1\",\"story\":\"J9.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Settings remove-helper confirmation. Assert these exact displayed values, availability, controls and state changes against fixture `J9.1`; apply D1–D7."
  },
  {
    "id": "J9.2",
    "node": "J9.2",
    "frame": "9.2 Helper removed",
    "state": "Settings/panel after helper removal",
    "navigation": "Remove success → component readings unavailable; status item remains",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J9.2\",\"story\":\"J9.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Settings/panel after helper removal. Assert these exact displayed values, availability, controls and state changes against fixture `J9.2`; apply D1–D7."
  },
  {
    "id": "J9.3",
    "node": "J9.3",
    "frame": "9.3 After Quit — status item gone (relaunch from Applications)",
    "state": "Post-quit state",
    "navigation": "Quit → no status item/process; relaunch → configured entry route",
    "expectedScene": "processInventory",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J9.3\",\"story\":\"J9.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Post-quit state. Assert these exact displayed values, availability, controls and state changes against fixture `J9.3`; apply D1–D7."
  },
  {
    "id": "J10.1",
    "node": "J10.1",
    "frame": "10.1 Right-click → Check for Updates…",
    "state": "Context menu entry and update launch",
    "navigation": "Secondary click → update action → J10.2",
    "expectedScene": "contextMenu",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J10.1\",\"story\":\"J10.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Context menu entry and update launch. Assert these exact displayed values, availability, controls and state changes against fixture `J10.1`; apply D1–D7."
  },
  {
    "id": "J10.2",
    "node": "J10.2",
    "frame": "10.2 Checking",
    "state": "Checking progress state",
    "navigation": "J10.1 action → checking; result → J10.3/J10.6/J10.7",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J10.2\",\"story\":\"J10.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Checking progress state. Assert these exact displayed values, availability, controls and state changes against fixture `J10.2`; apply D1–D7."
  },
  {
    "id": "J10.3",
    "node": "J10.3",
    "frame": "10.3 Update available",
    "state": "Update alert/window with release notes",
    "navigation": "Check result available → download/install actions; later → status item",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J10.3\",\"story\":\"J10.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Update alert/window with release notes. Assert these exact displayed values, availability, controls and state changes against fixture `J10.3`; apply D1–D7."
  },
  {
    "id": "J10.4",
    "node": "J10.4",
    "frame": "10.4 Downloading",
    "state": "Determinate/indeterminate download progress",
    "navigation": "Update available → download; cancel/later → prior state",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J10.4\",\"story\":\"J10.4\"}",
    "variants": [
      "base",
      "download-failed",
      "download-cancelled",
      "staging-failed"
    ],
    "acceptance": "Determinate/indeterminate download progress. Assert these exact displayed values, availability, controls and state changes against fixture `J10.4`; apply D1–D7."
  },
  {
    "id": "J10.5",
    "node": "J10.5",
    "frame": "10.5 Ready to install",
    "state": "100% ready-to-install state",
    "navigation": "Download complete → install and relaunch/later",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J10.5\",\"story\":\"J10.5\"}",
    "variants": [
      "base",
      "install-failed",
      "interrupted",
      "relaunch-failed"
    ],
    "acceptance": "100% ready-to-install state. Assert these exact displayed values, availability, controls and state changes against fixture `J10.5`; apply D1–D7."
  },
  {
    "id": "J10.6",
    "node": "J10.6",
    "frame": "10.6 Up to date",
    "state": "Up-to-date alert",
    "navigation": "Check success with no update → dismiss to status item",
    "expectedScene": "softwareUpdate",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J10.6\",\"story\":\"J10.6\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Up-to-date alert. Assert these exact displayed values, availability, controls and state changes against fixture `J10.6`; apply D1–D7."
  },
  {
    "id": "J10.7",
    "node": "J10.7",
    "frame": "10.7 Couldn’t check",
    "state": "Update-check failure with Try Again/OK",
    "navigation": "Network/service failure → retry or dismiss",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J10.7\",\"story\":\"J10.7\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Update-check failure with Try Again/OK. Assert these exact displayed values, availability, controls and state changes against fixture `J10.7`; apply D1–D7."
  },
  {
    "id": "J10.8",
    "node": "J10.8",
    "frame": "10.8 After relaunch → helper update (see 3.3)",
    "state": "Post-update helper update alert",
    "navigation": "Install/relaunch → J3.3; later → panel",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J10.8\",\"story\":\"J10.8\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Post-update helper update alert. Assert these exact displayed values, availability, controls and state changes against fixture `J10.8`; apply D1–D7."
  },
  {
    "id": "J12.1",
    "node": "J12.1",
    "frame": "12.1 Settings → Uninstall Watt?…",
    "state": "Settings General uninstall action",
    "navigation": "Settings Uninstall… → J12.2 confirmation",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J12.1\",\"story\":\"J12.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Settings General uninstall action. Assert these exact displayed values, availability, controls and state changes against fixture `J12.1`; apply D1–D7."
  },
  {
    "id": "J12.2",
    "node": "J12.2",
    "frame": "12.2 Confirm uninstall",
    "state": "Destructive uninstall alert",
    "navigation": "Confirm → J12.3; Cancel → settings",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J12.2\",\"story\":\"J12.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Destructive uninstall alert. Assert these exact displayed values, availability, controls and state changes against fixture `J12.2`; apply D1–D7."
  },
  {
    "id": "J12.3",
    "node": "J12.3",
    "frame": "12.3 Uninstalled — nothing left behind",
    "state": "Post-uninstall clean desktop",
    "navigation": "Uninstall success → process/helper/status item absent",
    "expectedScene": "processInventory",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J12.3\",\"story\":\"J12.3\"}",
    "variants": [
      "base",
      "remove-failed",
      "partial-cleanup",
      "interrupted"
    ],
    "acceptance": "Post-uninstall clean desktop. Assert these exact displayed values, availability, controls and state changes against fixture `J12.3`; apply D1–D7."
  },
  {
    "id": "J12.4",
    "node": "J12.4",
    "frame": "12.4 Dragged to Trash, reinstalled later → leftover helper found",
    "state": "Reconnect/remove-helper alert after reinstall",
    "navigation": "Reinstall detects helper → reconnect/remove helper; reconnect → J12.5",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J12.4\",\"story\":\"J12.4\"}",
    "variants": [
      "base",
      "reconnect-failed",
      "remove-failed",
      "timeout",
      "cancelled"
    ],
    "acceptance": "Reconnect/remove-helper alert after reinstall. Assert these exact displayed values, availability, controls and state changes against fixture `J12.4`; apply D1–D7."
  },
  {
    "id": "J12.5",
    "node": "J12.5",
    "frame": "12.5 Reconnected — continues at 1.6 (All set)",
    "state": "Reconnect success and all-set continuation",
    "navigation": "Reconnect → J1.6; status item/settings reflect helper connected",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J12.5\",\"story\":\"J12.5\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Reconnect success and all-set continuation. Assert these exact displayed values, availability, controls and state changes against fixture `J12.5`; apply D1–D7."
  },
  {
    "id": "J11.1",
    "node": "J11.1",
    "frame": "11.1 Status item + panel — VoiceOver order",
    "state": "Accessibility walkthrough for status item/panel",
    "navigation": "VoiceOver focus enters status item/panel in designed order",
    "expectedScene": "panel",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J11.1\",\"story\":\"J11.1\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Accessibility walkthrough for status item/panel. Assert these exact displayed values, availability, controls and state changes against fixture `J11.1`; apply D1–D7."
  },
  {
    "id": "J11.2",
    "node": "J11.2",
    "frame": "11.2 Settings — control labels & keyboard",
    "state": "Accessible settings labels/focus/order",
    "navigation": "Keyboard and VoiceOver traverse settings sections and controls",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J11.2\",\"story\":\"J11.2\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Accessible settings labels/focus/order. Assert these exact displayed values, availability, controls and state changes against fixture `J11.2`; apply D1–D7."
  },
  {
    "id": "J11.3",
    "node": "J11.3",
    "frame": "11.3 Destructive confirmation — keyboard",
    "state": "Accessible destructive confirmation",
    "navigation": "Default/cancel/destructive actions are announced and keyboard reachable",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"node\":\"J11.3\",\"story\":\"J11.3\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Accessible destructive confirmation. Assert these exact displayed values, availability, controls and state changes against fixture `J11.3`; apply D1–D7."
  }
]
"""#
        // Invalid checked-in data is a programmer error, not an unknown fixture fallback.
        return try! JSONDecoder().decode([StoryFixture].self, from: Data(json.utf8))
    }()
}
#endif
