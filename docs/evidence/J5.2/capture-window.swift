import AppKit
import CoreGraphics
import ApplicationServices

let pid = Int32(CommandLine.arguments[1])!
let directory = URL(fileURLWithPath: CommandLine.arguments[2])
func ownedWindows() -> [[String: Any]] {
    (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] ?? []).filter {
            ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
        }
}
let windows = ownedWindows()
let permitted = CGPreflightScreenCaptureAccess()
try JSONSerialization.data(withJSONObject: ["windows": windows, "screenCapturePreauthorized": permitted,
    "AXTrusted": AXIsProcessTrusted(), "fixture": "J5.2/base", "node": "30:4028",
    "timestampUTC": ISO8601DateFormatter().string(from: Date()), "liveInteractionVerified": false],
    options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("window.json"))
guard permitted else { print("BLOCKED: Screen capture not preauthorized; no permission requested"); exit(1) }
var count = 0
for window in windows {
    guard let id = window[kCGWindowNumber as String] as? NSNumber,
          ownedWindows().contains(where: { ($0[kCGWindowNumber as String] as? NSNumber) == id }) else { continue }
    let png = directory.appendingPathComponent("native-window-\(id).png")
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-o", "-l", id.stringValue, png.path]
    try capture.run(); capture.waitUntilExit()
    if capture.terminationStatus == 0, let data = try? Data(contentsOf: png),
       let bitmap = NSBitmapImageRep(data: data), bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 {
        count += 1
    }
}
print("Captured \(count) PID-scoped app-owned windows; capture alone does not prove comparable setup panel or AX interaction")
if count == 0 { print("BLOCKED: no capturable app-owned compositor window"); exit(1) }
