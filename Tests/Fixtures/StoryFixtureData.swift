#if DEBUG || SWIFT_PACKAGE
import Foundation

// Pinned F00 snapshot; regenerate only after inventory review. No runtime file lookup.
enum StoryFixtureData {
    static let stories: [StoryFixture] = {
        let json = #"""
[
  {
    "id": "C01",
    "node": "21:928",
    "frame": "1 · Status Panel — Charging",
    "state": "Panel: charging, +42.1 W, 64%, charger/system/battery rows and CPU/GPU/Display/Other rows",
    "navigation": "Menu-bar primary click → open panel; Settings… → Settings scene; Quit Watt? → terminate",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"app_owned_crop\":{\"height\":473.0,\"node\":\"29:8875\",\"width\":320.0,\"x\":551.0,\"y\":40.0},\"appearance\":\"dark\",\"canvas\":\"21:927\",\"crop_status\":\"metadata bounds; visually reviewed reference; native capture alignment not calibrated\",\"design_context\":\"21-928.context.json\",\"design_context_sha256\":\"a4f5aae9efafb0bc3f933da97805994cfe1dc1d2fdc5bdc7787c759e6a169bf1\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-612.0,\"y\":0.0},\"id\":\"21:929\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":641.0,\"x\":0.0,\"y\":5.0},\"id\":\"21:1047\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":473.0,\"width\":320.0,\"x\":551.0,\"y\":40.0},\"id\":\"29:8875\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":640.0,\"width\":900.0,\"x\":0.0,\"y\":0.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":640,\"path\":\"exports/21-928.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"606a1da3bf6ae57b74191a8734bc566471182f7ec3afbc39e96b21b9f136c908\",\"size_bytes\":561813,\"width_pixels\":900},\"frame_name\":\"1 · Status Panel — Charging\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"21:928\",\"order\":1,\"reference_pixels_per_figma_unit\":1,\"reference_png\":\"21-928.png\",\"reference_png_sha256\":\"3168aa9f9582767b01419895ac00bc81284fb34c636d2859bbf48addaa1ecb63\",\"story\":\"C01\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=21-928\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Panel: charging, +42.1 W, 64%, charger/system/battery rows and CPU/GPU/Display/Other rows. Assert these exact displayed values, availability, controls and state changes against fixture `C01`; apply D1–D7."
  },
  {
    "id": "C02",
    "node": "22:130",
    "frame": "2 · Status Panel — On Battery (Light)",
    "state": "Panel: on-battery, −18.4 W, remaining-time subtitle; light appearance",
    "navigation": "Menu-bar primary click in light mode → panel; rows remain the same semantic surface",
    "expectedScene": "panel",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-612.0,\"y\":0.0},\"id\":\"22:131\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":641.0,\"x\":0.0,\"y\":5.0},\"id\":\"22:410\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":473.0,\"width\":320.0,\"x\":551.0,\"y\":40.0},\"id\":\"29:9158\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":640.0,\"width\":900.0,\"x\":960.0,\"y\":0.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":640,\"path\":\"exports/22-130.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"fc3dba2b59d091674e7e8b38aa570b6643952e019a7da2e3adf0a10f3797540c\",\"size_bytes\":555815,\"width_pixels\":900},\"frame_name\":\"2 · Status Panel — On Battery (Light)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"22:130\",\"order\":2,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C02\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=22-130\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Panel: on-battery, −18.4 W, remaining-time subtitle; light appearance. Assert these exact displayed values, availability, controls and state changes against fixture `C02`; apply D1–D7."
  },
  {
    "id": "C03",
    "node": "22:1095",
    "frame": "3 · Secondary-Click Menu (Dark)",
    "state": "Dark status item context menu; action/submenu items, hover+keyboard, selected submenu",
    "navigation": "Status-item secondary click → menu; Open Watt? → panel; Settings… → settings; updates → update flow; Quit → terminate",
    "expectedScene": "contextMenu",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-612.0,\"y\":0.0},\"id\":\"22:1096\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":641.0,\"x\":0.0,\"y\":5.0},\"id\":\"22:1344\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":187.0,\"width\":230.0,\"x\":561.0,\"y\":38.0},\"id\":\"22:1345\",\"name\":\"Status Item Context Menu\"},{\"bounds\":{\"height\":141.0,\"width\":190.0,\"x\":375.0,\"y\":38.0},\"id\":\"22:1811\",\"name\":\"Show in Menu Bar · Submenu\"}],\"frame_bounds\":{\"height\":460.0,\"width\":900.0,\"x\":1920.0,\"y\":0.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":460,\"path\":\"exports/22-1095.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"ff92427c65d511524783f5f6f92ef3b39f2f2de5e736c8637c30f9263d451011\",\"size_bytes\":428143,\"width_pixels\":900},\"frame_name\":\"3 · Secondary-Click Menu (Dark)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"22:1095\",\"order\":3,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C03\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=22-1095\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark status item context menu; action/submenu items, hover+keyboard, selected submenu. Assert these exact displayed values, availability, controls and state changes against fixture `C03`; apply D1–D7."
  },
  {
    "id": "C04.1",
    "node": "24:390",
    "frame": "Delta · charging",
    "state": "Status item: charging delta",
    "navigation": "Menu-bar status item from charging telemetry → C01 panel",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:391\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:638\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":40.0,\"y\":60.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-390.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"22a43d638a7d52ff6a5169b63a5006da09196a2c13dede9029bc0b57ad5510ae\",\"size_bytes\":25745,\"width_pixels\":560},\"frame_name\":\"Delta · charging\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:390\",\"order\":4,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C04.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-390\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: charging delta. Assert these exact displayed values, availability, controls and state changes against fixture `C04.1`; apply D1–D7."
  },
  {
    "id": "C04.2",
    "node": "24:639",
    "frame": "Delta · on battery",
    "state": "Status item: negative battery delta",
    "navigation": "Menu-bar status item from on-battery telemetry → C02 panel",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:640\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:757\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":660.0,\"y\":60.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-639.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"32f76aff05a69231bc7f852139ea7cb131afc67ab8a2bbb8da77aba939eec6c8\",\"size_bytes\":25607,\"width_pixels\":560},\"frame_name\":\"Delta · on battery\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:639\",\"order\":5,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C04.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-639\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: negative battery delta. Assert these exact displayed values, availability, controls and state changes against fixture `C04.2`; apply D1–D7."
  },
  {
    "id": "C04.3",
    "node": "24:758",
    "frame": "Delta · charged, on adapter",
    "state": "Status item: full/charged adapter state",
    "navigation": "Menu-bar status item → charged panel state",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:759\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:876\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":40.0,\"y\":160.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-758.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"d45b3201b8c62558b68373bb07d05b1bd3c6e1e1966abe823df9c2b8927b1f37\",\"size_bytes\":25651,\"width_pixels\":560},\"frame_name\":\"Delta · charged, on adapter\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:758\",\"order\":6,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C04.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-758\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: full/charged adapter state. Assert these exact displayed values, availability, controls and state changes against fixture `C04.3`; apply D1–D7."
  },
  {
    "id": "C04.4",
    "node": "24:877",
    "frame": "Charger Input",
    "state": "Status item: charger input mode",
    "navigation": "Settings display mode → status item; click → panel",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:878\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:995\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":660.0,\"y\":160.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-877.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"5f0e7d03af3ecbdbeded1bea5a78ecaaa81dfd94c3969e177389ee3ce62d196c\",\"size_bytes\":25704,\"width_pixels\":560},\"frame_name\":\"Charger Input\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:877\",\"order\":7,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C04.4\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-877\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: charger input mode. Assert these exact displayed values, availability, controls and state changes against fixture `C04.4`; apply D1–D7."
  },
  {
    "id": "C04.5",
    "node": "24:996",
    "frame": "Charger Input · unplugged (falls back to System Draw)",
    "state": "Unplugged charger mode falls back to system draw",
    "navigation": "Telemetry loses charger → fallback status item and panel without stale charger value",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:997\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:1114\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":40.0,\"y\":260.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-996.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"6b8fc729a4882ae455b8ee3aa03cfb4a2629360ef7f5d07b6c912d8d2fb6c703\",\"size_bytes\":25562,\"width_pixels\":560},\"frame_name\":\"Charger Input · unplugged (falls back to System Draw)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:996\",\"order\":8,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C04.5\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-996\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Unplugged charger mode falls back to system draw. Assert these exact displayed values, availability, controls and state changes against fixture `C04.5`; apply D1–D7."
  },
  {
    "id": "C04.6",
    "node": "24:1115",
    "frame": "System Draw (desktop Macs)",
    "state": "Status item: system draw on a Mac with no battery",
    "navigation": "Desktop/no-battery capability → system draw status item and panel",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:1116\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:1233\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":660.0,\"y\":260.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-1115.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"26a6afb368236f903a764306fb73661fcb9d904dceb3a825924287a2997c97c8\",\"size_bytes\":25708,\"width_pixels\":560},\"frame_name\":\"System Draw (desktop Macs)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:1115\",\"order\":9,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C04.6\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-1115\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: system draw on a Mac with no battery. Assert these exact displayed values, availability, controls and state changes against fixture `C04.6`; apply D1–D7."
  },
  {
    "id": "C04.7",
    "node": "24:1234",
    "frame": "Per Component (max 2)",
    "state": "Status item: at most two component readings",
    "navigation": "Settings component selection → status item; click → component panel",
    "expectedScene": "statusItem",
    "appearance": "dark",
    "referenceJSON": "{\"app_owned_crop\":{\"height\":24.0,\"node\":\"24:1350\",\"width\":148.0,\"x\":153.0,\"y\":5.0},\"appearance\":\"dark\",\"canvas\":\"21:927\",\"crop_status\":\"metadata bounds; visually reviewed reference; native capture alignment not calibrated\",\"design_context\":\"24-1234.context.json\",\"design_context_sha256\":\"edf7662609ad61e32a779ed388a2c41917624c1446069b01ddb9dbfeef957f92\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:1235\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:1352\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":40.0,\"y\":360.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-1234.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"367eea96cab6497abf62498ef948638436c8ae743d7feb1facea7b00a735b088\",\"size_bytes\":26177,\"width_pixels\":560},\"frame_name\":\"Per Component (max 2)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:1234\",\"order\":10,\"reference_pixels_per_figma_unit\":1,\"reference_png\":\"24-1234.png\",\"reference_png_sha256\":\"09e4d331e4984fdbe6cbb6c14c1aad96a1f4f8addd330a5349bf83b9e0847612\",\"story\":\"C04.7\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-1234\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: at most two component readings. Assert these exact displayed values, availability, controls and state changes against fixture `C04.7`; apply D1–D7."
  },
  {
    "id": "C04.8",
    "node": "24:1353",
    "frame": "Icon Only (notch / crowded menu bar)",
    "state": "Status item icon-only fallback",
    "navigation": "Crowded/notch preference → icon-only status item; panel remains discoverable",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:1354\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:1471\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":660.0,\"y\":360.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-1353.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"4b33f8912f40cb40637b1603f24eddb3e6083826e6d5f751e3008fe03aefb80e\",\"size_bytes\":25323,\"width_pixels\":560},\"frame_name\":\"Icon Only (notch / crowded menu bar)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:1353\",\"order\":11,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C04.8\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-1353\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item icon-only fallback. Assert these exact displayed values, availability, controls and state changes against fixture `C04.8`; apply D1–D7."
  },
  {
    "id": "C04.9",
    "node": "24:1472",
    "frame": "No reading yet / sensor unavailable",
    "state": "Status item: no reading/sensor unavailable",
    "navigation": "Telemetry unavailable → no-reading status item; recovery → normal status item",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:1473\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:1590\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":40.0,\"y\":460.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-1472.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"02386467f2f5da30a584febf47d1098c298ff4e3f088c107b6cb1276cd1ca846\",\"size_bytes\":25350,\"width_pixels\":560},\"frame_name\":\"No reading yet / sensor unavailable\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:1472\",\"order\":12,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C04.9\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-1472\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Status item: no reading/sensor unavailable. Assert these exact displayed values, availability, controls and state changes against fixture `C04.9`; apply D1–D7."
  },
  {
    "id": "C04.10",
    "node": "24:1591",
    "frame": "Panel open (selected)",
    "state": "Selected status item while panel is open",
    "navigation": "Primary click opens selected state; close returns to unselected status item",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:1592\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:1710\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":660.0,\"y\":460.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-1591.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"e6a69b963d1c050e0f7f024c170579a99d8f660f925280bfbd4d71bd406c056c\",\"size_bytes\":25158,\"width_pixels\":560},\"frame_name\":\"Panel open (selected)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:1591\",\"order\":13,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C04.10\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-1591\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Selected status item while panel is open. Assert these exact displayed values, availability, controls and state changes against fixture `C04.10`; apply D1–D7."
  },
  {
    "id": "C04.11",
    "node": "24:1711",
    "frame": "Light menu bar · charging",
    "state": "Light menu-bar contrast variant while charging",
    "navigation": "System appearance/light menu bar → readable status item",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:1712\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:1959\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":40.0,\"y\":560.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-1711.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"e746435ca9e2d1599c24696abc7fa7f23d15d2ee44d9ff71176313baa4925a77\",\"size_bytes\":28605,\"width_pixels\":560},\"frame_name\":\"Light menu bar · charging\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:1711\",\"order\":14,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C04.11\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-1711\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Light menu-bar contrast variant while charging. Assert these exact displayed values, availability, controls and state changes against fixture `C04.11`; apply D1–D7."
  },
  {
    "id": "C04.12",
    "node": "24:1960",
    "frame": "Light menu bar · on battery",
    "state": "Light menu-bar contrast variant while on battery",
    "navigation": "System appearance/light menu bar + battery → readable status item",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-952.0,\"y\":0.0},\"id\":\"24:1961\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":301.0,\"x\":0.0,\"y\":5.0},\"id\":\"24:2078\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":44.0,\"width\":560.0,\"x\":660.0,\"y\":560.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":44,\"path\":\"exports/24-1960.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"a840d3bd2d3c53a65f99c514056a06c931406870a440d1e2841385bcb258b7bd\",\"size_bytes\":28431,\"width_pixels\":560},\"frame_name\":\"Light menu bar · on battery\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"24:1960\",\"order\":15,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C04.12\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=24-1960\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Light menu-bar contrast variant while on battery. Assert these exact displayed values, availability, controls and state changes against fixture `C04.12`; apply D1–D7."
  },
  {
    "id": "C05",
    "node": "25:787",
    "frame": "5 · Settings Window (Light)",
    "state": "Full grouped Settings window: Menu Bar, Readings, Component Readings, Notifications, General",
    "navigation": "Settings… from context/panel or app launch → settings; changes update shared preferences and status label",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"21:927\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":0.0,\"y\":0.0},\"id\":\"25:788\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":870.0,\"width\":580.0,\"x\":466.0,\"y\":56.0},\"id\":\"25:1102\",\"name\":\"Watt? Settings\"}],\"frame_bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":1400.0,\"y\":760.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":982,\"path\":\"exports/25-787.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"a79e104cc77794e6695491b6bf97515c983ec47ea6d64f6dbae180a8945e52f2\",\"size_bytes\":1271177,\"width_pixels\":1512},\"frame_name\":\"5 · Settings Window (Light)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"25:787\",\"order\":16,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"C05\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=25-787\"}",
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
    "node": "27:987",
    "frame": "1.1 Welcome",
    "state": "First-launch welcome; app icon placeholder; Continue",
    "navigation": "First launch → Continue to J1.2; close → J5.1 defaults/resume semantics",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"27:988\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":308.0,\"width\":480.0,\"x\":260.0,\"y\":216.0},\"id\":\"27:1302\",\"name\":\"Watt? Onboarding Window\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/27-987.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"bdbce1343aa0f2b7837b822ad12f97bdcf36d267b97bb02d711596f17a7ba71a\",\"size_bytes\":659226,\"width_pixels\":1000},\"frame_name\":\"1.1 Welcome\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"27:987\",\"order\":17,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J1.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=27-987\"}",
    "variants": [
      "base"
    ],
    "acceptance": "First-launch welcome; app icon placeholder; Continue. Assert these exact displayed values, availability, controls and state changes against fixture `J1.1`; apply D1–D7."
  },
  {
    "id": "J1.2",
    "node": "27:1354",
    "frame": "1.2 Choose a menu bar reading",
    "state": "Radio picker: Delta selected; Charger, Draw, Components descriptions",
    "navigation": "J1.1 Continue → this; Back → J1.1; Continue → J1.3; no-battery branch → J4.2",
    "expectedScene": "onboarding",
    "appearance": "light",
    "referenceJSON": "{\"app_owned_crop\":{\"height\":346.0,\"node\":\"27:1508\",\"width\":480.0,\"x\":260.0,\"y\":197.0},\"appearance\":\"light\",\"canvas\":\"27:985\",\"crop_status\":\"metadata bounds; visually reviewed reference; native capture alignment not calibrated\",\"design_context\":\"27-1354.context.json\",\"design_context_sha256\":\"f40ccccd6fbfa93b5553aaf870882539e1c9aad1d617f1494efed15e4c5a402e\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"27:1355\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":346.0,\"width\":480.0,\"x\":260.0,\"y\":197.0},\"id\":\"27:1508\",\"name\":\"Watt? Onboarding Window\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":1160.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/27-1354.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"3aa05d431b7832a68d4ab80b84b5c0bd76092409904decdec4e0fa58a756525c\",\"size_bytes\":642938,\"width_pixels\":1000},\"frame_name\":\"1.2 Choose a menu bar reading\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"27:1354\",\"order\":18,\"reference_pixels_per_figma_unit\":1,\"reference_png\":\"27-1354.png\",\"reference_png_sha256\":\"c7858c05c25fb0038a674a08bfd399c41065f34ca95a28f7bbfe12de744184e5\",\"story\":\"J1.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=27-1354\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Radio picker: Delta selected; Charger, Draw, Components descriptions. Assert these exact displayed values, availability, controls and state changes against fixture `J1.2`; apply D1–D7."
  },
  {
    "id": "J1.3",
    "node": "27:1584",
    "frame": "1.3 Offer component readings",
    "state": "Helper facts: what it reads, network access, remove it; Not Now and Turn On…",
    "navigation": "J1.2 Continue → this; Not Now → J1.6; Turn On… → J1.4",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"27:1585\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":412.0,\"width\":480.0,\"x\":260.0,\"y\":164.0},\"id\":\"27:1738\",\"name\":\"Watt? Onboarding Window\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":2240.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/27-1584.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"423e4d02e68de7bc702576f1a53ec4e04ccfe8449ff186b31b23bb197659ee5d\",\"size_bytes\":615322,\"width_pixels\":1000},\"frame_name\":\"1.3 Offer component readings\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"27:1584\",\"order\":19,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J1.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=27-1584\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Helper facts: what it reads, network access, remove it; Not Now and Turn On…. Assert these exact displayed values, availability, controls and state changes against fixture `J1.3`; apply D1–D7."
  },
  {
    "id": "J1.4",
    "node": "28:1206",
    "frame": "1.4 Waiting for approval (system notification)",
    "state": "Approval pending window + indeterminate spinner + system notification",
    "navigation": "J1.3 Enable → this; Open System Settings → external approval; Cancel/timeout → J3.1",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"28:1207\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":224.0,\"width\":480.0,\"x\":260.0,\"y\":258.0},\"id\":\"28:1521\",\"name\":\"Watt? Onboarding Window\"},{\"bounds\":{\"height\":88.0,\"width\":344.0,\"x\":644.0,\"y\":44.0},\"id\":\"28:1584\",\"name\":\"System Notification\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":3320.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/28-1206.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"3755e5354037425d8a2874c58f4d886aa698b430712a2b8244bc08053667e43b\",\"size_bytes\":697238,\"width_pixels\":1000},\"frame_name\":\"1.4 Waiting for approval (system notification)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"28:1206\",\"order\":20,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J1.4\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=28-1206\"}",
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
    "node": "28:1598",
    "frame": "1.5 Component readings on",
    "state": "Green success, live CPU/GPU/display preview",
    "navigation": "Approval success → this; Continue → J1.6",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"28:1599\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":364.0,\"width\":480.0,\"x\":260.0,\"y\":188.0},\"id\":\"28:1752\",\"name\":\"Watt? Onboarding Window\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":4400.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/28-1598.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"2133f820594f6514f02e1222d2e2735e0ab85bcc1a95d7b3df44d5616ea27ea7\",\"size_bytes\":625915,\"width_pixels\":1000},\"frame_name\":\"1.5 Component readings on\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"28:1598\",\"order\":21,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J1.5\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=28-1598\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Green success, live CPU/GPU/display preview. Assert these exact displayed values, availability, controls and state changes against fixture `J1.5`; apply D1–D7."
  },
  {
    "id": "J1.6",
    "node": "28:2199",
    "frame": "1.6 All set",
    "state": "All-set confirmation + Open at login switch",
    "navigation": "J1.5 Continue or reconnect → this; Done → J1.7/status item",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"28:2200\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":328.0,\"width\":480.0,\"x\":260.0,\"y\":206.0},\"id\":\"28:2353\",\"name\":\"Watt? Onboarding Window\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":5480.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/28-2199.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"7de9c607b695153a9ec739336b421a60f00af96f7228f44599ac3101760c299b\",\"size_bytes\":647921,\"width_pixels\":1000},\"frame_name\":\"1.6 All set\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"28:2199\",\"order\":22,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J1.6\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=28-2199\"}",
    "variants": [
      "base"
    ],
    "acceptance": "All-set confirmation + Open at login switch. Assert these exact displayed values, availability, controls and state changes against fixture `J1.6`; apply D1–D7."
  },
  {
    "id": "J1.7",
    "node": "28:2621",
    "frame": "1.7 First run — where Watt? lives",
    "state": "Coach mark/popover anchored to status item",
    "navigation": "J1.6 Done → coach mark; Got It → J1.8",
    "expectedScene": "coachMark",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"28:2622\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"28:2770\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":136.0,\"width\":260.0,\"x\":463.0,\"y\":33.0},\"id\":\"28:2771\",\"name\":\"Coach Mark (Popover)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":6560.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/28-2621.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"826e2663c1b97870f4bac0acae3e43a406c5dc84dc47846517decde8fc1eb867\",\"size_bytes\":784623,\"width_pixels\":1000},\"frame_name\":\"1.7 First run — where Watt? lives\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"28:2621\",\"order\":23,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J1.7\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=28-2621\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Coach mark/popover anchored to status item. Assert these exact displayed values, availability, controls and state changes against fixture `J1.7`; apply D1–D7."
  },
  {
    "id": "J1.8",
    "node": "28:2802",
    "frame": "1.8 First open — live panel",
    "state": "First live panel opened from status item",
    "navigation": "J1.7 Got It or click status item → C01/C02 according to reading",
    "expectedScene": "panel",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"28:2803\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"28:2952\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":473.0,\"width\":320.0,\"x\":645.0,\"y\":38.0},\"id\":\"29:9338\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":7640.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/28-2802.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"22b558c855b40a7ebd2c5e6b116bbc416d3cb0f96c9e10a233396de38e9e2a41\",\"size_bytes\":718094,\"width_pixels\":1000},\"frame_name\":\"1.8 First open — live panel\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"28:2802\",\"order\":24,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J1.8\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=28-2802\"}",
    "variants": [
      "base"
    ],
    "acceptance": "First live panel opened from status item. Assert these exact displayed values, availability, controls and state changes against fixture `J1.8`; apply D1–D7."
  },
  {
    "id": "J2.1",
    "node": "29:1549",
    "frame": "2.1 Per Component unavailable in menu",
    "state": "Context menu with disabled Per Component and Turn On Component Readings…",
    "navigation": "Secondary click → menu; enable action → J2.3/settings",
    "expectedScene": "contextMenu",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"29:1550\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"29:1860\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":187.0,\"width\":230.0,\"x\":651.0,\"y\":38.0},\"id\":\"29:1861\",\"name\":\"Menu\"},{\"bounds\":{\"height\":176.0,\"width\":250.0,\"x\":405.0,\"y\":38.0},\"id\":\"29:2197\",\"name\":\"Menu\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/29-1549.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"8f431d9b994445a83c96f57d6307bb60f948796b93d1107add85a62208f560f9\",\"size_bytes\":764441,\"width_pixels\":1000},\"frame_name\":\"2.1 Per Component unavailable in menu\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"29:1549\",\"order\":25,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J2.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=29-1549\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Context menu with disabled Per Component and Turn On Component Readings…. Assert these exact displayed values, availability, controls and state changes against fixture `J2.1`; apply D1–D7."
  },
  {
    "id": "J2.2",
    "node": "29:2456",
    "frame": "2.2 Panel — component readings off",
    "state": "Panel with component section off and setup action",
    "navigation": "J2.1 Open Watt? → panel; setup action → J2.3",
    "expectedScene": "panel",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"29:2457\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"29:2606\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":347.0,\"width\":320.0,\"x\":645.0,\"y\":38.0},\"id\":\"29:7572\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":1160.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/29-2456.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"07225ea2fae545cdd27fa64cbc895e710756962c49cabff99fa3e768529382b9\",\"size_bytes\":740001,\"width_pixels\":1000},\"frame_name\":\"2.2 Panel — component readings off\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"29:2456\",\"order\":26,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J2.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=29-2456\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Panel with component section off and setup action. Assert these exact displayed values, availability, controls and state changes against fixture `J2.2`; apply D1–D7."
  },
  {
    "id": "J2.3",
    "node": "29:3270",
    "frame": "2.3 Settings — turn on (excerpt)",
    "state": "Settings excerpt showing Component Readings status/helper controls",
    "navigation": "J2.2 or context action → settings; enable → J2.4",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"29:3271\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":288.0,\"width\":520.0,\"x\":240.0,\"y\":226.0},\"id\":\"29:3424\",\"name\":\"Watt? Settings\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":2240.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/29-3270.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"4b2d1d879e694c954a252a5a4302322fde23dddc98cadf6c2d373d2f759d1ad0\",\"size_bytes\":653976,\"width_pixels\":1000},\"frame_name\":\"2.3 Settings — turn on (excerpt)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"29:3270\",\"order\":27,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J2.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=29-3270\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Settings excerpt showing Component Readings status/helper controls. Assert these exact displayed values, availability, controls and state changes against fixture `J2.3`; apply D1–D7."
  },
  {
    "id": "J2.4",
    "node": "29:3926",
    "frame": "2.4 Waiting for approval (from Settings)",
    "state": "Approval notification launched from Settings",
    "navigation": "J2.3 enable → pending; approval success → J2.5; cancellation → J3.1",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"29:3927\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":269.0,\"width\":520.0,\"x\":240.0,\"y\":236.0},\"id\":\"29:4080\",\"name\":\"Watt? Settings\"},{\"bounds\":{\"height\":88.0,\"width\":344.0,\"x\":644.0,\"y\":44.0},\"id\":\"29:4578\",\"name\":\"System Notification\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":3320.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/29-3926.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"9e019931466db050cdb2967c6e0c828e0d5d6973330b45684d02609725c545f8\",\"size_bytes\":666794,\"width_pixels\":1000},\"frame_name\":\"2.4 Waiting for approval (from Settings)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"29:3926\",\"order\":28,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J2.4\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=29-3926\"}",
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
    "node": "29:4590",
    "frame": "2.5 Turned on — Per Component available",
    "state": "Settings/panel after helper is enabled; Per Component available",
    "navigation": "J2.4 success → settings/panel; select mode → C04.7",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"29:4591\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":311.0,\"width\":520.0,\"x\":240.0,\"y\":215.0},\"id\":\"29:4744\",\"name\":\"Watt? Settings\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"29:5251\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":4400.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/29-4590.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"483fc23819b23e264f5f52f3f50fa8e0acc616894a45cbf4dd5059780c0f7276\",\"size_bytes\":641959,\"width_pixels\":1000},\"frame_name\":\"2.5 Turned on — Per Component available\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"29:4590\",\"order\":29,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J2.5\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=29-4590\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Injected authenticated helper only; Show=Components; Components=CPU, GPU; Two fit.; Status=On; Remove…; CPU 9.8 · GPU 4.1 W. Removal, disabled readings, disconnect and revoked approval fail closed. Exact reference: docs/evidence/J2.5/reference.json; visual/live AX/system approval remain unverified. Apply D1–D7."
  },
  {
    "id": "J3.1",
    "node": "29:5253",
    "frame": "3.1 Approval not given (timed out or cancelled)",
    "state": "Approval failure with retry/continue-without path",
    "navigation": "J1.4/J2.4 cancellation or timeout → this; retry → approval; continue → panel without helper",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"29:5254\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":260.0,\"width\":260.0,\"x\":370.0,\"y\":222.0},\"id\":\"29:5407\",\"name\":\"Alert\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/29-5253.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"eac914e4716ad6235d95a37e8c987aaf8b761a6f0cb480422fccda5632794a8c\",\"size_bytes\":769027,\"width_pixels\":1000},\"frame_name\":\"3.1 Approval not given (timed out or cancelled)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"29:5253\",\"order\":30,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J3.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=29-5253\"}",
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
    "node": "29:5439",
    "frame": "3.2 Helper switched off later in System Settings",
    "state": "Verified helper loss: native panel, Delta fallback, Fix… → Settings",
    "navigation": "Runtime helper loss → this; re-enable → approval; dismiss → panel no component rows",
    "expectedScene": "statusPanel",
    "appearance": "dark",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"29:5440\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"29:5688\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":347.0,\"width\":320.0,\"x\":645.0,\"y\":38.0},\"id\":\"29:9518\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":1160.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/29-5439.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"c7826cdeabf83c38421f0ef57cb4e4cff81a6b2ce1694400b8542a76976496e4\",\"size_bytes\":734882,\"width_pixels\":1000},\"frame_name\":\"3.2 Helper switched off later in System Settings\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"29:5439\",\"order\":31,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J3.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=29-5439\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Injected authenticated connection then disconnect; dark native panel; +42.1 W; Charger input 65.0 W; System draw 22.9 W; Battery +42.1 W; exclamationmark.triangle.fill; Helper is off; Showing Delta until it’s back.; Fix… opens Settings. No fabricated components. Exact reference and blocked visual evidence: docs/evidence/J3.2. Apply D1–D7."
  },
  {
    "id": "J3.3",
    "node": "29:6181",
    "frame": "3.3 Helper needs updating after app update",
    "state": "Helper update required alert and Update Helper action",
    "navigation": "Post-update check → this; Update Helper → relaunch/approval; Later → panel",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"29:6182\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":246.0,\"width\":260.0,\"x\":370.0,\"y\":230.0},\"id\":\"29:6335\",\"name\":\"Alert\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":2240.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/29-6181.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"02b17f63cd1fe517adbdb63365f443d1780b46a08a2ca3822bc59c590cacb8a1\",\"size_bytes\":767793,\"width_pixels\":1000},\"frame_name\":\"3.3 Helper needs updating after app update\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"29:6181\",\"order\":32,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J3.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=29-6181\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native scene-attached alert: The helper changed; Update Helper; Later. Exact reference docs/evidence/J3.3/reference.json. Receipt-specific signed relaunch and helper installation/authenticated approval required. Old protocol migration unsupported. No fake OS success; live/AX/visual blocked."
  },
  {
    "id": "J4.1",
    "node": "30:2275",
    "frame": "4.1 Welcome (desktop copy)",
    "state": "First-launch welcome copy for desktop Mac/no battery",
    "navigation": "Desktop first launch → J4.2; close → J5.1",
    "expectedScene": "onboarding",
    "appearance": "dark",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"30:2276\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":308.0,\"width\":480.0,\"x\":260.0,\"y\":216.0},\"id\":\"30:2528\",\"name\":\"Watt? Onboarding Window\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/30-2275.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"f7cc535fe827890fbc18934fd4c475d3cf92c789a141514738e266be875da011\",\"size_bytes\":658854,\"width_pixels\":1000},\"frame_name\":\"4.1 Welcome (desktop copy)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"30:2275\",\"order\":33,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J4.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=30-2275\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Explicit desktop welcome: Know your watts; Watt? sits in your menu bar and shows what your Mac draws. Nothing more. Continue uses existing persisted picker route; J4.2 capability variant remains separate. Native close/Escape, WattAppIcon asset, isolated Debug storage. Evidence: docs/evidence/J4.1; visual/live acceptance blocked."
  },
  {
    "id": "J4.2",
    "node": "30:2576",
    "frame": "4.2 Choose reading — battery options unavailable",
    "state": "Radio picker with battery choices disabled",
    "navigation": "J4.1 Continue → this; Draw/System Draw → J4.3; Back → J4.1",
    "expectedScene": "onboarding",
    "appearance": "dark",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"30:2577\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":346.0,\"width\":480.0,\"x\":260.0,\"y\":197.0},\"id\":\"30:2699\",\"name\":\"Watt? Onboarding Window\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":1160.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/30-2576.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"8d6531c66cb072c93d448f884175d2d1d8a0cf912861181a05fad0a2fe1b4987\",\"size_bytes\":643638,\"width_pixels\":1000},\"frame_name\":\"4.2 Choose reading — battery options unavailable\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"30:2576\",\"order\":34,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J4.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=30-2576\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native no-battery radio picker: Draw selected (38.2 W); Components helper-gated; Delta/Charger disabled. Back persists welcome; Continue preserves existing helperOffer routing, never approval. In-memory Debug fixture. Evidence docs/evidence/J4.2; AX/live/comparable visual acceptance blocked."
  },
  {
    "id": "J4.3",
    "node": "30:2786",
    "frame": "4.3 Panel — system draw only (continues at 1.3 for components)",
    "state": "Desktop panel with system draw only",
    "navigation": "J4.2 Continue → panel; component path continues at J1.3 if offered",
    "expectedScene": "panel",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"30:2787\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"30:2905\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":335.0,\"width\":320.0,\"x\":661.0,\"y\":38.0},\"id\":\"30:2930\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":2240.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/30-2786.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"0234d877866d786319fc6894fc7a841389c0631b83c257e29507ca418fab079f\",\"size_bytes\":730417,\"width_pixels\":1000},\"frame_name\":\"4.3 Panel — system draw only (continues at 1.3 for components)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"30:2786\",\"order\":35,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J4.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=30-2786\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native desktop Drawing panel: 38.2 W, Mac Studio no-battery subtitle, CPU 14.6 W, GPU 11.2 W, SSD 1.9 W, Other 10.5 W. No battery/charger rows. Settings and Quit reuse production actions. Base Debug fixture isolated; helper-off, stale and unavailable states never fabricate components. Evidence docs/evidence/J4.3; visual/AX acceptance fail closed."
  },
  {
    "id": "J5.1",
    "node": "30:3675",
    "frame": "5.1 Welcome closed → running with defaults",
    "state": "Welcome closed; Delta defaults applied; light top-trailing coach mark; setup deferred",
    "navigation": "Close welcome → coach mark; Not Now → running with defaults; Finish Setup → J1.2 picker",
    "expectedScene": "coachMark",
    "appearance": "light",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"30:3676\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"30:3985\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":122.0,\"width\":310.0,\"x\":413.0,\"y\":33.0},\"id\":\"30:3986\",\"name\":\"Coach Mark (Popover)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/30-3675.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"f43875d659167b3bddd088b60f54e6ed62e123999581340c04e0d49e0f19c1e4\",\"size_bytes\":784419,\"width_pixels\":1000},\"frame_name\":\"5.1 Welcome closed → running with defaults\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"30:3675\",\"order\":36,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J5.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=30-3675\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native light top-trailing CoachMarkView: Watt? is on, showing Delta. / Setup can wait. Two steps, whenever you’re ready. / Not Now / Finish Setup. Not Now persists running/default state; Finish Setup persists picker state. Stale actions are ignored. Base Debug fixture isolated; evidence docs/evidence/J5.1; visual/AX acceptance fail closed."
  },
  {
    "id": "J5.2",
    "node": "30:4028",
    "frame": "5.2 Panel — finish setup prompt",
    "state": "Panel prompt to finish setup",
    "navigation": "J5.1 click status item → this; Continue… → J1.2 picker",
    "expectedScene": "panel",
    "appearance": "light",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"30:4029\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"30:4178\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":319.0,\"width\":320.0,\"x\":645.0,\"y\":38.0},\"id\":\"30:4197\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":1160.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/30-4028.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"2c840e0aa0a58288935d01e0fef2eb2aa9ab0e43b8cc5fdf1ec517973ae8e598\",\"size_bytes\":742752,\"width_pixels\":1000},\"frame_name\":\"5.2 Panel — finish setup prompt\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"30:4028\",\"order\":37,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J5.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=30-4028\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native light panel: Finish setup / 2 steps left / Continue… above Charger input 65.0 W, System draw 22.9 W, Battery +42.1 W, Settings… and Quit Watt?. Selected status item +42.1 W. Continue persists incomplete J1.2 picker; stale/repeated/failed writes do not navigate. Base Debug fixture isolated; evidence docs/evidence/J5.2; visual/AX acceptance fail closed."
  },
  {
    "id": "J5.3",
    "node": "30:4788",
    "frame": "5.3 Right-click — Finish Setup… (resumes at 1.2)",
    "state": "Context menu Finish Setup… resumes onboarding",
    "navigation": "J5.1 secondary click → this; Finish Setup → J1.2",
    "expectedScene": "contextMenu",
    "appearance": "light",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"30:4789\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"30:4938\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":222.0,\"width\":230.0,\"x\":645.0,\"y\":38.0},\"id\":\"30:4939\",\"name\":\"Menu\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":2240.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/30-4788.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"47a03bc59a0cf89010dd60c6d00c92e7c6a3624050c90ac82240c48889e57737\",\"size_bytes\":774455,\"width_pixels\":1000},\"frame_name\":\"5.3 Right-click — Finish Setup… (resumes at 1.2)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"30:4788\",\"order\":38,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J5.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=30-4788\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native light NSMenu: conditional Finish Setup… first action row and separator, Show in Menu Bar submenu, separator, Open Watt?, Settings… cmd-comma, separator, About Watt?, Check for Updates…, separator, Quit Watt? cmd-Q. Finish Setup persists incomplete J1.2 picker only for a current eligible menu action; changed/completed/repeated/stale actions and failed writes do not navigate. Base Debug fixture isolated; evidence docs/evidence/J5.3; visual/AX acceptance fail closed."
  },
  {
    "id": "J6.1",
    "node": "31:2745",
    "frame": "6.1 Plugged in — charging",
    "state": "Dark Aqua; selected +42.1 W; 320×265 native panel; Components hidden",
    "navigation": "Status item click → native charging panel; Settings… → settings; Quit Watt? → terminate",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"31:2746\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"31:2994\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":265.0,\"width\":320.0,\"x\":645.0,\"y\":38.0},\"id\":\"31:3013\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/31-2745.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"fa93d6f6e977ccc47ded70262e55eeaf2f6cac0fac3de502401030f5aa99b316\",\"size_bytes\":744128,\"width_pixels\":1000},\"frame_name\":\"6.1 Plugged in — charging\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"31:2745\",\"order\":39,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J6.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-2745\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark Aqua native MenuBarExtra window at 320×265 points, selected +42.1 W status item, Charging / +42.1 W / 64% · full in about 38 min. Native grouped Form/LabeledContent: Charger input / 96 W USB-C charger / 65.0 W; System draw / 22.9 W; Battery / +42.1 W. Hide Components; native borderless Settings… and Quit Watt? callbacks. Exact isolated J6.1/base only; unavailable values remain unavailable. Evidence docs/evidence/J6.1; missing native compositor/AX evidence blocks visual acceptance."
  },
  {
    "id": "J6.2",
    "node": "31:3754",
    "frame": "6.2 On adapter — charging on hold",
    "state": "Dark Aqua; selected 0.0 W; Holding at 80%; 320×279 native panel; Components hidden",
    "navigation": "Verified optimised hold → native panel; Settings… → settings; Quit Watt? → terminate",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"31:3755\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"31:3873\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":279.0,\"width\":320.0,\"x\":660.0,\"y\":38.0},\"id\":\"31:3892\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":1160.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/31-3754.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"4200ab7465f5fb6c2f5ad8ca5d7a6c4125604503bb5c50301810f86a7bb840bb\",\"size_bytes\":744201,\"width_pixels\":1000},\"frame_name\":\"6.2 On adapter — charging on hold\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"31:3754\",\"order\":40,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J6.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-3754\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark Aqua native MenuBarExtra window at 320×279 points, selected battery glyph and 0.0 W. Holding at 80% / 0.0 W / Because Optimised Battery Charging is on. Charging resumes before you usually unplug. Native grouped Form/LabeledContent: Charger input / 96 W USB-C charger / 21.4 W; System draw / 21.4 W; Battery / 0.0 W. No Components. Native borderless Settings… and Quit Watt?. Require explicit hold reason and fresh valid telemetry; unavailable/failure values fail closed. Isolated Debug J6.2/base only. Exact reference docs/evidence/J6.2/reference.json; missing compositor/AX evidence blocks visual acceptance."
  },
  {
    "id": "J6.3",
    "node": "31:4355",
    "frame": "6.3 On adapter — fully charged",
    "state": "Dark Aqua; selected 0.0 W; Full; 320×265 native panel; Components hidden",
    "navigation": "Verified full telemetry → native panel; Settings… → settings; Quit Watt? → terminate",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"31:4356\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"31:4474\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":265.0,\"width\":320.0,\"x\":660.0,\"y\":38.0},\"id\":\"31:4493\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":2240.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/31-4355.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"906e25b72b31f72ef9878f7251fe9e53b620d848c0713d0e48eed19fb0500206\",\"size_bytes\":742131,\"width_pixels\":1000},\"frame_name\":\"6.3 On adapter — fully charged\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"31:4355\",\"order\":41,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J6.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-4355\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark Aqua native MenuBarExtra window at 320×265 points, selected 0.0 W status item, Full / 0.0 W / 100% · running straight off the charger. Native grouped Form/LabeledContent: Charger input / 96 W USB-C charger / 19.8 W; System draw / 19.8 W; Battery / 0.0 W. Hide Components; native borderless Settings… and Quit Watt? callbacks. Require validated fresh available full-battery and adapter telemetry; connection alone never infers full. Exact isolated J6.3/base only; unsupported notification variants fail closed. Evidence docs/evidence/J6.3; missing native compositor/AX evidence blocks visual acceptance."
  },
  {
    "id": "J6.4",
    "node": "31:4956",
    "frame": "6.4 Charger can’t keep up (notification + panel)",
    "state": "Insufficient charger notification and panel",
    "navigation": "Charger threshold event → notification + panel; dismiss preserves reading",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"31:4957\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"31:5075\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":279.0,\"width\":320.0,\"x\":645.0,\"y\":38.0},\"id\":\"31:5094\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"},{\"bounds\":{\"height\":88.0,\"width\":344.0,\"x\":644.0,\"y\":520.0},\"id\":\"31:5557\",\"name\":\"System Notification\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":3320.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/31-4956.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"0b0382eb3b2d2f4355d859c2e85cf3f59450a4fc343f6be37e2ffc87fea1b941\",\"size_bytes\":746842,\"width_pixels\":1000},\"frame_name\":\"6.4 Charger can’t keep up (notification + panel)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"31:4956\",\"order\":42,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J6.4\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-4956\"}",
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
    "node": "31:5571",
    "frame": "6.5 Unplugged — on battery",
    "state": "Unplugged/on-battery state",
    "navigation": "Power source change → on-battery panel/status; estimate shown when valid",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"31:5572\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"31:5690\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":265.0,\"width\":320.0,\"x\":644.0,\"y\":38.0},\"id\":\"31:5709\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":4400.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/31-5571.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"908705b893cdac4224515a132a187a2e7883384de9843082b5394cd78e9576b0\",\"size_bytes\":742461,\"width_pixels\":1000},\"frame_name\":\"6.5 Unplugged — on battery\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"31:5571\",\"order\":43,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J6.5\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-5571\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark Aqua native MenuBarExtra window at 320×265 points, selected battery glyph and −18.4 W. On battery / −18.4 W / 64% · about 4 h 10 min left. Native grouped Form/LabeledContent: Charger input / Unplugged; System draw / 18.4 W; Battery / −18.4 W. No Components. Native borderless Settings… and Quit Watt? callbacks. Reuse generic on-battery telemetry; unavailable, invalid or stale values fail closed without fabricated estimates. Isolated Debug J6.5/base only; malformed or unsupported selectors reject. Exact reference docs/evidence/J6.5/reference.json; missing compositor/AX evidence blocks visual acceptance."
  },
  {
    "id": "J7.1",
    "node": "31:6173",
    "frame": "7.1 Right-click → Show in Menu Bar",
    "state": "Context menu submenu with display modes",
    "navigation": "Secondary click → submenu; select mode → J7.2/J7.4 or C04 states",
    "expectedScene": "contextMenu",
    "appearance": "light",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"31:6174\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"31:6484\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":187.0,\"width\":230.0,\"x\":651.0,\"y\":38.0},\"id\":\"31:6485\",\"name\":\"Menu\"},{\"bounds\":{\"height\":141.0,\"width\":190.0,\"x\":465.0,\"y\":38.0},\"id\":\"31:6717\",\"name\":\"Menu\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/31-6173.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"3d047cbe3448fc4d987f0440d47030ddc8b65012a26f054c12eae4d5f67c66a3\",\"size_bytes\":775538,\"width_pixels\":1000},\"frame_name\":\"7.1 Right-click → Show in Menu Bar\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"31:6173\",\"order\":44,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J7.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-6173\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native light AppKit status-item context menu and Show in Menu Bar submenu: Delta checked, Components natively highlighted. Frozen +42.1 W sampleCharging; completed onboarding; components/helper on; isolated Debug J7.1/base only. Shared preference mutations and AppRouter callbacks retain Finish Setup and helper-unavailable semantics. No custom menu chrome. Exact supplied reference docs/evidence/J7.1/reference.json; visual acceptance requires live PID-owned compositor/AX evidence."
  },
  {
    "id": "J7.2",
    "node": "31:6952",
    "frame": "7.2 Result — Per Component in menu bar",
    "state": "Compact result state with per-component menu label",
    "navigation": "J7.1 select Per Component → status item; click → component panel",
    "expectedScene": "statusItem",
    "appearance": "light",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"31:6953\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"31:7101\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":220.0,\"width\":1000.0,\"x\":1160.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":220,\"path\":\"exports/31-6952.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"e9c65d95a6157519f53c4dfc68bcafaf5055385189ee5e29340d90eb915411ff\",\"size_bytes\":236283,\"width_pixels\":1000},\"frame_name\":\"7.2 Result — Per Component in menu bar\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"31:6952\",\"order\":45,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J7.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-6952\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native Light status item: CPU 9.8 · GPU 4.1 W, no symbol. Shared MenuBarStatusLabel/PowerReading/PreferencesStore ordering and compact units. Isolated Debug J7.2/base only, frozen samplePerComponent and in-memory preferences, completed livePanel onboarding. Unavailable/stale/invalid data fails closed; max-two selection preserves order. Native macOS owns chrome, typography, spacing and placement. Exact supplied reference docs/evidence/J7.2/reference.json; visual acceptance requires live PID-owned compositor/AX capture."
  },
  {
    "id": "J7.3",
    "node": "31:7102",
    "frame": "7.3 Settings — choose components (max 2)",
    "state": "Settings component picker with max-two validation",
    "navigation": "J7.1 Settings → this; select up to two; save updates status item",
    "expectedScene": "settings",
    "appearance": "light",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"31:7103\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":229.0,\"width\":520.0,\"x\":240.0,\"y\":256.0},\"id\":\"31:7256\",\"name\":\"Watt? Settings\"},{\"bounds\":{\"height\":130.0,\"width\":170.0,\"x\":570.0,\"y\":406.0},\"id\":\"31:7533\",\"name\":\"Components pop-up menu (multi-select, max 2)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":2240.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/31-7102.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"8db7f6dbf19438d66f5701a36e08013779d04942663bba19103ee5cc4ed1d9ac\",\"size_bytes\":688879,\"width_pixels\":1000},\"frame_name\":\"7.3 Settings — choose components (max 2)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"31:7102\",\"order\":46,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J7.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-7102\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native Settings Form/LabeledContent and NSPopUpButton/NSMenu: Show Components; Two fit. More crowd the menu bar.; CPU, GPU checked; Display, SSD, Other disabled by available identity; Precision 42.1 W. Shared ordered max-two persisted selection; stale/unavailable action revalidation. Isolated DEBUG J7.3/base through native Settings route. Exact reference docs/evidence/J7.3; live PID/AX/compositor visual acceptance required."
  },
  {
    "id": "J7.4",
    "node": "31:7764",
    "frame": "7.4 Crowded menu bar — Icon Only",
    "state": "Compact icon-only status result",
    "navigation": "Crowded layout → icon-only fallback; click still opens panel",
    "expectedScene": "statusItem",
    "appearance": "light",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"31:7765\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"31:7913\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":220.0,\"width\":1000.0,\"x\":3320.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":220,\"path\":\"exports/31-7764.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"d99e2eadbc66f95a01c661ded137c3889f916e0063fb525c58694976586de3b3\",\"size_bytes\":235293,\"width_pixels\":1000},\"frame_name\":\"7.4 Crowded menu bar — Icon Only\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"31:7764\",\"order\":47,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J7.4\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-7764\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Native unselected Light battery.100percent.bolt template SF Symbol without visible text. Shared Icon Only preference and truthful accessible reading; J7.1 context routing preserved. Isolated DEBUG J7.4/base. Exact reference docs/evidence/J7.4; visual acceptance requires live PID-owned compositor/AX proof."
  },
  {
    "id": "J8.1",
    "node": "32:3451",
    "frame": "8.1 No reading (e.g. just after wake)",
    "state": "Panel/status item no-reading state",
    "navigation": "Wake/sensor gap → no-reading state; no false alert; recovery → J8.2",
    "expectedScene": "panel",
    "appearance": "dark",
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"32:3452\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"32:3700\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":195.0,\"width\":320.0,\"x\":670.0,\"y\":38.0},\"id\":\"32:3701\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/32-3451.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"9c9fd3f396bc4ac2dbf408b8785c107a1a16471adff6fd7a908b845b47584609\",\"size_bytes\":752290,\"width_pixels\":1000},\"frame_name\":\"8.1 No reading (e.g. just after wake)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"32:3451\",\"order\":48,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J8.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=32-3451\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Dark native MenuBarExtra: No reading / − − W / Usually right after wake. Watt? tries again every few seconds. Native Try now row, bordered Try Again, borderless Settings… and Quit Watt?. Selected bolt.fill and − − W status. Shared fail-closed reading state and refresh path; isolated DEBUG J8.1/base only. Exact reference docs/evidence/J8.1; visual acceptance requires PID/AX/compositor proof."
  },
  {
    "id": "J8.2",
    "node": "32:4456",
    "frame": "8.2 Readings resume automatically (no alert)",
    "state": "Recovered compact state with no alert",
    "navigation": "Telemetry resumes → normal panel/status; preserve selected mode",
    "expectedScene": "statusItem",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"32:4457\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"32:4574\",\"name\":\"Status Item Anchor (right-aligned)\"}],\"frame_bounds\":{\"height\":220.0,\"width\":1000.0,\"x\":1160.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":220,\"path\":\"exports/32-4456.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"202888272184e508e92e1e786e70301ad8adbedb9758c0d5e414eb5827a23c65\",\"size_bytes\":224138,\"width_pixels\":1000},\"frame_name\":\"8.2 Readings resume automatically (no alert)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"32:4456\",\"order\":49,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J8.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=32-4456\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Recovered compact state with no alert. Assert these exact displayed values, availability, controls and state changes against fixture `J8.2`; apply D1–D7."
  },
  {
    "id": "J8.3",
    "node": "32:4575",
    "frame": "8.3 Opening Watt? again from Finder or Spotlight shows Settings",
    "state": "App relaunch/open routes to Settings",
    "navigation": "Finder/Spotlight launch → settings scene when already configured",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"32:4576\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"32:4892\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":311.0,\"width\":520.0,\"x\":240.0,\"y\":215.0},\"id\":\"32:4893\",\"name\":\"Watt? Settings\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":2240.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/32-4575.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"7dccac13b2d83978dacabea90ae91f4874ca60f68f1490b31c72859f91b08586\",\"size_bytes\":642158,\"width_pixels\":1000},\"frame_name\":\"8.3 Opening Watt? again from Finder or Spotlight shows Settings\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"32:4575\",\"order\":50,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J8.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=32-4575\"}",
    "variants": [
      "base"
    ],
    "acceptance": "App relaunch/open routes to Settings. Assert these exact displayed values, availability, controls and state changes against fixture `J8.3`; apply D1–D7."
  },
  {
    "id": "J9.1",
    "node": "32:5397",
    "frame": "9.1 Settings → Remove… (confirm)",
    "state": "Settings remove-helper confirmation",
    "navigation": "Settings Remove… → confirmation; Cancel returns; Remove → J9.2",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"32:5398\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"32:7851\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":187.0,\"width\":520.0,\"x\":240.0,\"y\":277.0},\"id\":\"32:5551\",\"name\":\"Watt? Settings\"},{\"bounds\":{\"height\":260.0,\"width\":260.0,\"x\":370.0,\"y\":230.0},\"id\":\"32:5813\",\"name\":\"Alert\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/32-5397.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"d23a0b2810db505c3f77faaf54562f573cfc1c7cb24ac3f3bfed7cfe06fa986b\",\"size_bytes\":716632,\"width_pixels\":1000},\"frame_name\":\"9.1 Settings → Remove… (confirm)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"32:5397\",\"order\":51,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J9.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=32-5397\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Settings remove-helper confirmation. Assert these exact displayed values, availability, controls and state changes against fixture `J9.1`; apply D1–D7."
  },
  {
    "id": "J9.2",
    "node": "32:5844",
    "frame": "9.2 Helper removed",
    "state": "Settings/panel after helper removal",
    "navigation": "Remove success → component readings unavailable; status item remains",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"32:5845\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"32:6000\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":269.0,\"width\":520.0,\"x\":240.0,\"y\":236.0},\"id\":\"32:6001\",\"name\":\"Watt? Settings\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":1160.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/32-5844.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"ef5aeaabe1fc78fdc79bb994cf7a3bb637edc0218905dc25846ebe1547070ba8\",\"size_bytes\":658910,\"width_pixels\":1000},\"frame_name\":\"9.2 Helper removed\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"32:5844\",\"order\":52,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J9.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=32-5844\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Settings/panel after helper removal. Assert these exact displayed values, availability, controls and state changes against fixture `J9.2`; apply D1–D7."
  },
  {
    "id": "J9.3",
    "node": "32:6494",
    "frame": "9.3 After Quit — status item gone (relaunch from Applications)",
    "state": "Post-quit state",
    "navigation": "Quit → no status item/process; relaunch → configured entry route",
    "expectedScene": "processInventory",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"32:6495\",\"name\":\"Desktop Template\"}],\"frame_bounds\":{\"height\":220.0,\"width\":1000.0,\"x\":2240.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":220,\"path\":\"exports/32-6494.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"907bb54ddba1f9c562d7606785348cf3716b3ffb86b3c479aac03e74aa366119\",\"size_bytes\":234949,\"width_pixels\":1000},\"frame_name\":\"9.3 After Quit — status item gone (relaunch from Applications)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"32:6494\",\"order\":53,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J9.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=32-6494\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Post-quit state. Assert these exact displayed values, availability, controls and state changes against fixture `J9.3`; apply D1–D7."
  },
  {
    "id": "J10.1",
    "node": "34:3836",
    "frame": "10.1 Right-click → Check for Updates…",
    "state": "Context menu entry and update launch",
    "navigation": "Secondary click → update action → J10.2",
    "expectedScene": "contextMenu",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"34:3837\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"34:4147\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":187.0,\"width\":230.0,\"x\":651.0,\"y\":38.0},\"id\":\"34:4148\",\"name\":\"Menu\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/34-3836.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"f724934a4090344cc5ea9b6868ae8f6d984656b51517837a41777b59f4399aaf\",\"size_bytes\":779008,\"width_pixels\":1000},\"frame_name\":\"10.1 Right-click → Check for Updates…\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"34:3836\",\"order\":54,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J10.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=34-3836\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Context menu entry and update launch. Assert these exact displayed values, availability, controls and state changes against fixture `J10.1`; apply D1–D7."
  },
  {
    "id": "J10.2",
    "node": "34:4482",
    "frame": "10.2 Checking",
    "state": "Checking progress state",
    "navigation": "J10.1 action → checking; result → J10.3/J10.6/J10.7",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"34:4483\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":177.0,\"width\":420.0,\"x\":290.0,\"y\":282.0},\"id\":\"34:4636\",\"name\":\"Window · Software Update\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":1160.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/34-4482.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"64aa1647369956225110186084ba2848cf232fd0b95d1a50cd719cabfe6c6301\",\"size_bytes\":725816,\"width_pixels\":1000},\"frame_name\":\"10.2 Checking\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"34:4482\",\"order\":55,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J10.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=34-4482\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Checking progress state. Assert these exact displayed values, availability, controls and state changes against fixture `J10.2`; apply D1–D7."
  },
  {
    "id": "J10.3",
    "node": "34:4695",
    "frame": "10.3 Update available",
    "state": "Update alert/window with release notes",
    "navigation": "Check result available → download/install actions; later → status item",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"34:4696\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":365.0,\"width\":520.0,\"x\":240.0,\"y\":188.0},\"id\":\"34:4849\",\"name\":\"Window · Software Update\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":2240.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/34-4695.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"f9db0d2814519243c46d1da9c387c328ccb8cd9a5bec713042de70da3b3df90b\",\"size_bytes\":624418,\"width_pixels\":1000},\"frame_name\":\"10.3 Update available\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"34:4695\",\"order\":56,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J10.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=34-4695\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Update alert/window with release notes. Assert these exact displayed values, availability, controls and state changes against fixture `J10.3`; apply D1–D7."
  },
  {
    "id": "J10.4",
    "node": "34:5339",
    "frame": "10.4 Downloading",
    "state": "Determinate/indeterminate download progress",
    "navigation": "Update available → download; cancel/later → prior state",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"34:5340\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":177.0,\"width\":420.0,\"x\":290.0,\"y\":282.0},\"id\":\"34:5493\",\"name\":\"Window · Software Update\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":3320.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/34-5339.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"f765c7545b2e7ac2717f3676b5eeb25e7f012e9368256a020d07ca8c5766b26c\",\"size_bytes\":726022,\"width_pixels\":1000},\"frame_name\":\"10.4 Downloading\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"34:5339\",\"order\":57,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J10.4\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=34-5339\"}",
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
    "node": "34:5608",
    "frame": "10.5 Ready to install",
    "state": "100% ready-to-install state",
    "navigation": "Download complete → install and relaunch/later",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"34:5609\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":177.0,\"width\":420.0,\"x\":290.0,\"y\":282.0},\"id\":\"34:5762\",\"name\":\"Window · Software Update\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":4400.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/34-5608.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"ba9ea1cde56ab255eb4a8c85e1f852867159fdeaa0ec2bab453775904b7c854e\",\"size_bytes\":728849,\"width_pixels\":1000},\"frame_name\":\"10.5 Ready to install\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"34:5608\",\"order\":58,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J10.5\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=34-5608\"}",
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
    "node": "34:5822",
    "frame": "10.6 Up to date",
    "state": "Up-to-date alert",
    "navigation": "Check success with no update → dismiss to status item",
    "expectedScene": "softwareUpdate",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"34:5823\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":198.0,\"width\":260.0,\"x\":370.0,\"y\":261.0},\"id\":\"34:5976\",\"name\":\"Alert\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":5480.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/34-5822.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"9e2af9d932d087afeaea7ceaefd9a3749ca10760df88e12919f4eb1c42944855\",\"size_bytes\":767122,\"width_pixels\":1000},\"frame_name\":\"10.6 Up to date\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"34:5822\",\"order\":59,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J10.6\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=34-5822\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Up-to-date alert. Assert these exact displayed values, availability, controls and state changes against fixture `J10.6`; apply D1–D7."
  },
  {
    "id": "J10.7",
    "node": "34:6003",
    "frame": "10.7 Couldn’t check",
    "state": "Update-check failure with Try Again/OK",
    "navigation": "Network/service failure → retry or dismiss",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"34:6004\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":246.0,\"width\":260.0,\"x\":370.0,\"y\":230.0},\"id\":\"34:6157\",\"name\":\"Alert\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":6560.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/34-6003.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"99182e7e28862267a9cdde51e6a9b4b071ca584c361818d43b5b8da42318bbd0\",\"size_bytes\":767349,\"width_pixels\":1000},\"frame_name\":\"10.7 Couldn’t check\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"34:6003\",\"order\":60,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J10.7\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=34-6003\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Update-check failure with Try Again/OK. Assert these exact displayed values, availability, controls and state changes against fixture `J10.7`; apply D1–D7."
  },
  {
    "id": "J10.8",
    "node": "34:6183",
    "frame": "10.8 After relaunch → helper update (see 3.3)",
    "state": "Post-update helper update alert",
    "navigation": "Install/relaunch → J3.3; later → panel",
    "expectedScene": "update",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"34:6184\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"34:6339\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":246.0,\"width\":260.0,\"x\":370.0,\"y\":230.0},\"id\":\"34:6340\",\"name\":\"Alert\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":7640.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/34-6183.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"8ae169f771652df9039b08893f9666b57ead89d8c8076d04cf44f77a153a7eae\",\"size_bytes\":768711,\"width_pixels\":1000},\"frame_name\":\"10.8 After relaunch → helper update (see 3.3)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"34:6183\",\"order\":61,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J10.8\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=34-6183\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Post-update helper update alert. Assert these exact displayed values, availability, controls and state changes against fixture `J10.8`; apply D1–D7."
  },
  {
    "id": "J12.1",
    "node": "35:4360",
    "frame": "12.1 Settings → Uninstall Watt?…",
    "state": "Settings General uninstall action",
    "navigation": "Settings Uninstall… → J12.2 confirmation",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"35:4361\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"35:4677\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":271.0,\"width\":540.0,\"x\":230.0,\"y\":235.0},\"id\":\"35:4678\",\"name\":\"Watt? Settings\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/35-4360.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"1ca2e14c190002b250e3ba0a8bf92cbc67350ba5c5d2364e2530a16a938a8659\",\"size_bytes\":658955,\"width_pixels\":1000},\"frame_name\":\"12.1 Settings → Uninstall Watt?…\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"35:4360\",\"order\":62,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J12.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=35-4360\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Settings General uninstall action. Assert these exact displayed values, availability, controls and state changes against fixture `J12.1`; apply D1–D7."
  },
  {
    "id": "J12.2",
    "node": "35:5144",
    "frame": "12.2 Confirm uninstall",
    "state": "Destructive uninstall alert",
    "navigation": "Confirm → J12.3; Cancel → settings",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"35:5145\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"35:5300\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":187.0,\"width\":540.0,\"x\":230.0,\"y\":277.0},\"id\":\"35:5301\",\"name\":\"Watt? Settings\"},{\"bounds\":{\"height\":260.0,\"width\":260.0,\"x\":370.0,\"y\":223.0},\"id\":\"35:5568\",\"name\":\"Alert\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":1160.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/35-5144.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"f9625f9ac7f7d46ec8ca840376945ba0034330f9d4d6b41bd38ebfcaa6082b7e\",\"size_bytes\":715866,\"width_pixels\":1000},\"frame_name\":\"12.2 Confirm uninstall\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"35:5144\",\"order\":63,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J12.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=35-5144\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Destructive uninstall alert. Assert these exact displayed values, availability, controls and state changes against fixture `J12.2`; apply D1–D7."
  },
  {
    "id": "J12.3",
    "node": "35:5599",
    "frame": "12.3 Uninstalled — nothing left behind",
    "state": "Post-uninstall clean desktop",
    "navigation": "Uninstall success → process/helper/status item absent",
    "expectedScene": "processInventory",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"35:5600\",\"name\":\"Desktop Template\"}],\"frame_bounds\":{\"height\":220.0,\"width\":1000.0,\"x\":2240.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":220,\"path\":\"exports/35-5599.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"907bb54ddba1f9c562d7606785348cf3716b3ffb86b3c479aac03e74aa366119\",\"size_bytes\":234949,\"width_pixels\":1000},\"frame_name\":\"12.3 Uninstalled — nothing left behind\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"35:5599\",\"order\":64,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J12.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=35-5599\"}",
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
    "node": "35:5746",
    "frame": "12.4 Dragged to Trash, reinstalled later → leftover helper found",
    "state": "Reconnect/remove-helper alert after reinstall",
    "navigation": "Reinstall detects helper → reconnect/remove helper; reconnect → J12.5",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"35:5747\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":246.0,\"width\":260.0,\"x\":370.0,\"y\":222.0},\"id\":\"35:5900\",\"name\":\"Alert\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":3320.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/35-5746.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"c733e05b4765822e63de542ca6780b7b6f25b2b671b4c5f3204db77edcaddabf\",\"size_bytes\":768763,\"width_pixels\":1000},\"frame_name\":\"12.4 Dragged to Trash, reinstalled later → leftover helper found\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"35:5746\",\"order\":65,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J12.4\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=35-5746\"}",
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
    "node": "35:5926",
    "frame": "12.5 Reconnected — continues at 1.6 (All set)",
    "state": "Reconnect success and all-set continuation",
    "navigation": "Reconnect → J1.6; status item/settings reflect helper connected",
    "expectedScene": "onboarding",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Responsive behavior\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"35:5927\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"35:6082\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":206.0,\"width\":540.0,\"x\":230.0,\"y\":267.0},\"id\":\"35:6083\",\"name\":\"Watt? Settings\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":4400.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/35-5926.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"21df5ba62438b833d73f4b275801b51a0a1ba9bd7d25326d1b2724f9fca584cd\",\"size_bytes\":685668,\"width_pixels\":1000},\"frame_name\":\"12.5 Reconnected — continues at 1.6 (All set)\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"35:5926\",\"order\":66,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J12.5\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=35-5926\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Reconnect success and all-set continuation. Assert these exact displayed values, availability, controls and state changes against fixture `J12.5`; apply D1–D7."
  },
  {
    "id": "J11.1",
    "node": "36:5057",
    "frame": "11.1 Status item + panel — VoiceOver order",
    "state": "Accessibility walkthrough for status item/panel",
    "navigation": "VoiceOver focus enters status item/panel in designed order",
    "expectedScene": "panel",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Accessibility\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-612.0,\"y\":0.0},\"id\":\"36:5058\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":641.0,\"x\":0.0,\"y\":5.0},\"id\":\"36:5059\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":473.0,\"width\":320.0,\"x\":551.0,\"y\":40.0},\"id\":\"36:5061\",\"name\":\"Watt? Panel (MenuBarExtra .window)\"}],\"frame_bounds\":{\"height\":640.0,\"width\":900.0,\"x\":80.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":640,\"path\":\"exports/36-5057.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"654ac9f732cdf8c69a337ec5055dcbb2816e6b308679afe0eb6098b0cbda8e02\",\"size_bytes\":561812,\"width_pixels\":900},\"frame_name\":\"11.1 Status item + panel — VoiceOver order\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"36:5057\",\"order\":67,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J11.1\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=36-5057\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Accessibility walkthrough for status item/panel. Assert these exact displayed values, availability, controls and state changes against fixture `J11.1`; apply D1–D7."
  },
  {
    "id": "J11.2",
    "node": "36:5186",
    "frame": "11.2 Settings — control labels & keyboard",
    "state": "Accessible settings labels/focus/order",
    "navigation": "Keyboard and VoiceOver traverse settings sections and controls",
    "expectedScene": "settings",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Accessibility\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":0.0,\"y\":0.0},\"id\":\"36:5187\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":870.0,\"width\":580.0,\"x\":466.0,\"y\":56.0},\"id\":\"36:5188\",\"name\":\"Watt? Settings\"}],\"frame_bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":1060.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":982,\"path\":\"exports/36-5186.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"b47d35a79fd208c8c931dad855153c20bda444c1b744c6ab4eee5bc6add1d498\",\"size_bytes\":1271180,\"width_pixels\":1512},\"frame_name\":\"11.2 Settings — control labels & keyboard\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"36:5186\",\"order\":68,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J11.2\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=36-5186\"}",
    "variants": [
      "base"
    ],
    "acceptance": "Accessible settings labels/focus/order. Assert these exact displayed values, availability, controls and state changes against fixture `J11.2`; apply D1–D7."
  },
  {
    "id": "J11.3",
    "node": "36:5428",
    "frame": "11.3 Destructive confirmation — keyboard",
    "state": "Accessible destructive confirmation",
    "navigation": "Default/cancel/destructive actions are announced and keyboard reachable",
    "expectedScene": "alert",
    "appearance": null,
    "referenceJSON": "{\"app_owned_crop\":null,\"appearance\":null,\"canvas\":\"27:985\",\"design_sections\":[\"Source of truth\",\"Information architecture\",\"Components\",\"Interaction states\",\"Accessibility\"],\"direct_child_bounds\":[{\"bounds\":{\"height\":982.0,\"width\":1512.0,\"x\":-512.0,\"y\":0.0},\"id\":\"36:5429\",\"name\":\"Desktop Template\"},{\"bounds\":{\"height\":24.0,\"width\":741.0,\"x\":0.0,\"y\":5.0},\"id\":\"36:5430\",\"name\":\"Status Item Anchor (right-aligned)\"},{\"bounds\":{\"height\":187.0,\"width\":540.0,\"x\":230.0,\"y\":277.0},\"id\":\"36:5432\",\"name\":\"Watt? Settings\"},{\"bounds\":{\"height\":260.0,\"width\":260.0,\"x\":370.0,\"y\":223.0},\"id\":\"36:5433\",\"name\":\"Alert\"}],\"frame_bounds\":{\"height\":720.0,\"width\":1000.0,\"x\":2652.0,\"y\":100.0},\"frame_export\":{\"dimensions_match_frame_bounds\":true,\"height_pixels\":720,\"path\":\"exports/36-5428.png\",\"pixels_per_figma_unit\":1,\"provenance\":\"conductor_figma_mcp_exports_2026_09_20\",\"sha256\":\"f9625f9ac7f7d46ec8ca840376945ba0034330f9d4d6b41bd38ebfcaa6082b7e\",\"size_bytes\":715866,\"width_pixels\":1000},\"frame_name\":\"11.3 Destructive confirmation — keyboard\",\"metadata_verified\":true,\"native_render_verified\":false,\"node\":\"36:5428\",\"order\":69,\"reference_pixels_per_figma_unit\":null,\"reference_png\":null,\"story\":\"J11.3\",\"url\":\"https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=36-5428\"}",
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
