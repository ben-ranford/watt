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
    "fixture": "J10.2/base", "node": "34:4482", "windowNode": "34:4636",
    "processIdentifier": pid, "windows": windows, "AXTrusted": ax,
    "screenCapturePreauthorized": screen, "score": NSNull(), "pixel_diff": NSNull(),
    "visualPass": false, "timestampUTC": ISO8601DateFormatter().string(from: Date())
]
var reason = "Capture blocked: Screen Recording or Accessibility not preauthorized; no permission requested."
if screen && ax {
    let application = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(application, 1)
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value)
    record["AXWindowsResult"] = result.rawValue
    if result == .success, let window = windows.first(where: { $0[kCGWindowName as String] as? String == "Software Update" }),
       let number = window[kCGWindowNumber as String] as? NSNumber {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", "-o", "-l", number.stringValue, directory.appendingPathComponent("native-window.png").path]
        try task.run()
        task.waitUntilExit()
        record["captureExit"] = task.terminationStatus
        reason = "PID-owned capture attempted; visual review and live Cancel interaction not yet verified."
    } else { reason = "Capture blocked: PID-owned Software Update window/AX identity unavailable." }
}
record["reason"] = reason
try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("window.json"))
print(reason)
