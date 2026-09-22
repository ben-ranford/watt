import AppKit
import ApplicationServices
import CoreGraphics

guard CommandLine.arguments.count == 3,
      let pid = Int32(CommandLine.arguments[1]), pid > 0 else {
    fputs("Usage: capture-window.swift PID OUTPUT_DIRECTORY\n", stderr)
    exit(2)
}
let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
func ownedWindows() -> [[String: Any]] {
    (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] ?? []).filter {
        ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
    }
}
func bounds(_ window: [String: Any]) -> CGRect? {
    guard let raw = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
    return CGRect(dictionaryRepresentation: raw)
}
var evidence: [String: Any] = [
    "fixture": "J8.2/base", "node": "32:4456", "processIdentifier": pid,
    "timestampUTC": ISO8601DateFormatter().string(from: Date()),
    "windows": ownedWindows(), "screenCapturePreauthorized": CGPreflightScreenCaptureAccess(),
    "AXTrusted": AXIsProcessTrusted(), "status": "blocked", "visualPass": false,
    "score": NSNull(), "pixel_diff": NSNull(), "comparableCapture": false,
    "selectedStatusItemVerified": false,
    "captureAPI": "screencapture -l; PID/AX/content/geometry-verified native status item"
]
func finish(_ reason: String, status: Int32 = 1) -> Never {
    evidence["reason"] = reason
    do {
        try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("window.json"))
    } catch { fputs("Could not save evidence: \(error)\n", stderr); exit(2) }
    print(reason)
    exit(status)
}
guard kill(pid, 0) == 0 else { finish("BLOCKED: Fixture PID is no longer alive") }
guard CGPreflightScreenCaptureAccess() else { finish("BLOCKED: Screen capture not preauthorized; no permission requested") }
guard AXIsProcessTrusted() else { finish("BLOCKED: Accessibility trust unavailable; no permission requested") }
let windows = ownedWindows()
guard !windows.isEmpty else { finish("BLOCKED: No fixture PID-owned on-screen compositor windows") }
guard let data = try? Data(contentsOf: directory.appendingPathComponent("capture-attempt.json")),
      let metadata = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      metadata["fixture"] as? String == "J8.2/base",
      metadata["node"] as? String == "32:4456",
      (metadata["processIdentifier"] as? NSNumber)?.int32Value == pid,
      metadata["appearance"] as? String == NSAppearance.Name.darkAqua.rawValue,
      metadata["panelPresented"] as? Bool == false,
      let reading = metadata["reading"] as? [String: Any],
      reading["text"] as? String == "+42.1 W",
      reading["accessibility"] as? String == "+42.1 watts",
      let anchor = metadata["statusItem"] as? [String: Any],
      let anchorID = anchor["windowNumber"] as? NSNumber else {
    finish("BLOCKED: Native PID, recovered copy, dark appearance or no-panel identity unproven")
}
evidence["nativeMetadata"] = metadata
guard let anchorWindow = windows.first(where: { ($0[kCGWindowNumber as String] as? NSNumber) == anchorID }) else {
    finish("BLOCKED: Native status anchor has no fixture PID-owned compositor window")
}
evidence["selectedStatusItemVerified"] = true
guard let id = anchorWindow[kCGWindowNumber as String] as? NSNumber else {
    finish("BLOCKED: Missing native status compositor ID")
}
let output = directory.appendingPathComponent("native-status-anchor.png")
let capture = Process()
capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
capture.arguments = ["-x", "-o", "-l", id.stringValue, output.path]
do { try capture.run(); capture.waitUntilExit() }
catch { finish("BLOCKED: Compositor capture failed: \(error)") }
guard capture.terminationStatus == 0,
      let data = try? Data(contentsOf: output),
      let bitmap = NSBitmapImageRep(data: data), bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 else {
    try? FileManager.default.removeItem(at: output)
    finish("BLOCKED: Invalid native status-item capture")
}
evidence["captures"] = ["native-status-anchor.png"]
evidence["status"] = "captured-awaiting-review"
evidence["comparableCapture"] = true
finish("Native PID/AX/compositor capture proven; visual review remains pending", status: 0)
