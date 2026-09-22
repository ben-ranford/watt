import AppKit
import ApplicationServices
import CoreGraphics

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
let watt = windows.filter { ($0[kCGWindowOwnerName as String] as? String)?.lowercased().contains("watt") == true }
let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
let trusted = AXIsProcessTrusted()
let screen = CGPreflightScreenCaptureAccess()
var record: [String: Any] = [
    "fixture": "J12.3/base", "node": "35:5599", "AXTrusted": trusted,
    "screenCapturePreauthorized": screen, "frontmostBundleIdentifier": front ?? "",
    "wattWindows": watt, "compositorWindowCount": windows.count,
    "visualPass": false, "score": NSNull(), "pixel_diff": NSNull(),
    "comparableCapture": false, "productionUninstallVerified": false,
    "method": "Controlled no-Watt launch followed by read-only native compositor inventory"
]
let canCapture = screen && trusted && !windows.isEmpty && watt.isEmpty && front == "com.apple.finder"
record["capturePermitted"] = canCapture
record["reason"] = canCapture
    ? "Native desktop eligible for capture; inspect before comparison, system-owned pixels differ by host."
    : "No valid Finder-only comparison: AX/TCC, compositor visibility or frontmost app requirements unavailable. No desktop fabricated."
try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("capture-attempt.json"))
exit(canCapture ? 0 : 1)
