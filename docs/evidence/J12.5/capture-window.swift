import AppKit
import ApplicationServices
import CoreGraphics
guard CommandLine.arguments.count == 3, let pid = Int32(CommandLine.arguments[1]) else { exit(2) }
let directory = URL(fileURLWithPath: CommandLine.arguments[2])
let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []).filter {
    ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
}
let screen = CGPreflightScreenCaptureAccess()
let ax = AXIsProcessTrusted()
var record: [String: Any] = [
    "fixture": "J12.5/base", "node": "35:5926", "windowNode": "35:6083",
    "processIdentifier": pid, "windows": windows, "AXTrusted": ax,
    "screenCapturePreauthorized": screen, "score": NSNull(), "pixel_diff": NSNull(),
    "visualPass": false, "timestampUTC": ISO8601DateFormatter().string(from: Date())
]
var reason = windows.isEmpty ? "Blocked: no visible PID-owned Settings window within the bounded launch attempt; AX trust unavailable, no permission requested." : "Capture blocked: Screen Recording not preauthorized; no permission requested."
if ax {
    let application = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(application, 1)
    var value: CFTypeRef?
    record["AXWindowsResult"] = AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value).rawValue
}
if screen, let window = windows.first,
   let number = window[kCGWindowNumber as String] as? NSNumber {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    task.arguments = ["-x", "-o", "-l", number.stringValue, directory.appendingPathComponent("native-window.png").path]
    try task.run()
    task.waitUntilExit()
    record["captureExit"] = task.terminationStatus
    reason = ax ? "PID-owned image captured; numerical comparison not performed." : "PID-owned image captured; AX comparison blocked by Accessibility TCC. No numerical comparison performed."
}
record["reason"] = reason
try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("window.json"))
print(reason)
