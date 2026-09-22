import AppKit
import CoreGraphics
import ApplicationServices

let pid = Int32(CommandLine.arguments[1])!
let directory = URL(fileURLWithPath: CommandLine.arguments[2])
let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []).filter {
        ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
    }
let permitted = CGPreflightScreenCaptureAccess()
try JSONSerialization.data(withJSONObject: ["windows": windows, "screenCapturePreauthorized": permitted,
    "AXTrusted": AXIsProcessTrusted(), "fixture": "J3.2/base", "liveInteractionVerified": false],
    options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("window.json"))
guard permitted else { print("BLOCKED: Screen capture not preauthorized; no permission requested"); exit(1) }
var count = 0
for window in windows {
    guard let id = window[kCGWindowNumber as String] as? NSNumber else { continue }
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-o", "-l", id.stringValue, directory.appendingPathComponent("native-window-\(id).png").path]
    try capture.run(); capture.waitUntilExit()
    if capture.terminationStatus == 0 { count += 1 }
}
print("Captured \(count) PID-scoped app-owned windows; no AX interaction or desktop capture")
if count == 0 { print("BLOCKED: no capturable app-owned compositor window"); exit(1) }
