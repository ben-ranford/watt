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
    "fixture": "J9.2/base", "node": "32:5844", "processIdentifier": pid,
    "timestampUTC": ISO8601DateFormatter().string(from: Date()),
    "windows": ownedWindows(), "screenCapturePreauthorized": CGPreflightScreenCaptureAccess(),
    "AXTrusted": AXIsProcessTrusted(), "status": "blocked", "visualPass": false,
    "score": NSNull(), "pixel_diff": NSNull(), "comparableCapture": false,
    "settingsWindowVerified": false,
    "captureAPI": "screencapture -l; PID/AX/content/geometry-verified native Settings scene"
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
// Read only the fixture PID's AX hierarchy; never infer an alert from window existence.
func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}
var strings: [String] = []
func inspect(_ element: AXUIElement, depth: Int = 0) {
    guard depth < 25 else { return }
    for key in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute] {
        if let text = attribute(element, key) as? String { strings.append(text) }
    }
    for child in (attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []) {
        inspect(child, depth: depth + 1)
    }
}
inspect(AXUIElementCreateApplication(pid))
evidence["AXStrings"] = strings
for required in ["Status", "Off", "Helper", "Turn On…", "Delta"] {
    guard strings.contains(required) else { finish("BLOCKED: Exact native removed-state content unproven: " + required) }
}
evidence["removedContentVerified"] = true
let windows = ownedWindows()
guard !windows.isEmpty else { finish("BLOCKED: No fixture PID-owned on-screen compositor windows") }
guard let data = try? Data(contentsOf: directory.appendingPathComponent("capture-attempt.json")),
      let metadata = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      metadata["fixture"] as? String == "J9.2/base",
      metadata["node"] as? String == "32:5844",
      (metadata["processIdentifier"] as? NSNumber)?.int32Value == pid,
      metadata["title"] as? String == "Watt? Settings",
      metadata["displayMode"] as? String == "Delta",
      metadata["showSymbol"] as? Bool == true,
      let windowID = metadata["settingsWindowNumber"] as? NSNumber else {
    finish("BLOCKED: Native PID, Settings title, configured values or window identity unproven")
}
evidence["nativeMetadata"] = metadata
guard let compositorWindow = windows.first(where: {
    ($0[kCGWindowNumber as String] as? NSNumber) == windowID
}) else {
    finish("BLOCKED: Settings scene has no fixture PID-owned compositor window")
}
evidence["settingsWindowVerified"] = true
guard let compositorID = compositorWindow[kCGWindowNumber as String] as? NSNumber,
      let compositorBounds = bounds(compositorWindow), compositorBounds.width > 0, compositorBounds.height > 0 else {
    finish("BLOCKED: Missing valid native Settings compositor bounds")
}
evidence["compositorBounds"] = NSStringFromRect(compositorBounds)
let output = directory.appendingPathComponent("native-settings-window.png")
let capture = Process()
capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
capture.arguments = ["-x", "-o", "-l", compositorID.stringValue, output.path]
do { try capture.run(); capture.waitUntilExit() }
catch { finish("BLOCKED: Compositor capture failed: \(error)") }
guard capture.terminationStatus == 0,
      let data = try? Data(contentsOf: output),
      let bitmap = NSBitmapImageRep(data: data), bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 else {
    try? FileManager.default.removeItem(at: output)
    finish("BLOCKED: Invalid native Settings capture")
}
evidence["captures"] = ["native-settings-window.png"]
evidence["status"] = "captured-awaiting-review"
evidence["comparableCapture"] = false
// A Settings-only image is not a full Settings-plus-alert reference comparison.
finish("Native Settings capture proven; status-item capture and live button interaction remain pending", status: 0)
