import AppKit
import CoreGraphics
import ApplicationServices

// Require app PID ownership, live AX panel content and matching compositor geometry.
// Never request TCC access, cache a view, invent a window, or capture the desktop.
guard CommandLine.arguments.count == 3, let pid = Int32(CommandLine.arguments[1]), pid > 0 else {
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
let windows = ownedWindows()
let permitted = CGPreflightScreenCaptureAccess()
let trusted = AXIsProcessTrusted()
var evidence: [String: Any] = [
    "windows": windows, "screenCapturePreauthorized": permitted, "AXTrusted": trusted,
    "fixture": "J6.3/base", "node": "31:4355", "processIdentifier": pid,
    "timestampUTC": ISO8601DateFormatter().string(from: Date()),
    "liveInteractionVerified": false, "visualPass": false, "score": NSNull(),
    "pixel_diff": NSNull(), "nativeCapture": NSNull(), "status": "blocked",
    "comparableCapture": false,
    "captureAPI": "screencapture -l; AX-content/geometry-verified app-owned native panel only"
]
func finish(_ reason: String, status: Int32 = 1) -> Never {
    evidence["reason"] = reason
    do {
        try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("window.json"))
    } catch {
        fputs("Could not write capture evidence: \(error)\n", stderr)
        exit(2)
    }
    print(reason)
    exit(status)
}
guard permitted else { finish("BLOCKED: Screen capture not preauthorized; no permission requested") }
guard trusted else { finish("BLOCKED: Accessibility trust unavailable; no permission requested") }
guard !windows.isEmpty else { finish("BLOCKED: No app-owned on-screen compositor windows") }
func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
    return value
}
func content(_ element: AXUIElement, depth: Int = 0) -> [String] {
    guard depth < 30 else { return [] }
    let strings = [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute].compactMap {
        attribute(element, $0) as? String
    }
    let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    return strings + children.flatMap { content($0, depth: depth + 1) }
}
func frame(_ element: AXUIElement) -> CGRect? {
    guard let pointRef = attribute(element, kAXPositionAttribute),
          let sizeRef = attribute(element, kAXSizeAttribute),
          CFGetTypeID(pointRef) == AXValueGetTypeID(),
          CFGetTypeID(sizeRef) == AXValueGetTypeID() else { return nil }
    let pointValue = pointRef as! AXValue
    let sizeValue = sizeRef as! AXValue
    var point = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(pointValue, .cgPoint, &point),
          AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
    return CGRect(origin: point, size: size)
}
let app = AXUIElementCreateApplication(pid)
let axWindows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
evidence["AXWindowCount"] = axWindows.count
let expected = ["Full", "0.0 W",
                "100% · running straight off the charger",
                "Charger input", "96 W USB-C charger", "19.8 W", "System draw", "Battery", "Settings…", "Quit Watt?"]
let panels = axWindows.filter { window in
    let text = content(window).joined(separator: "\n")
    return expected.allSatisfy { text.contains($0) } && !text.contains("Components")
}
guard panels.count == 1, let panel = panels.first, let panelFrame = frame(panel) else {
    finish("BLOCKED: No unique live AX fully-charged-on-adapter panel matches exact content with Components hidden")
}
evidence["AXPanelContent"] = content(panel)
func matches(_ window: [String: Any]) -> Bool {
    guard let raw = window[kCGWindowBounds as String] as? NSDictionary,
          let bounds = CGRect(dictionaryRepresentation: raw) else { return false }
    return abs(bounds.minX - panelFrame.minX) <= 2 && abs(bounds.minY - panelFrame.minY) <= 2
        && abs(bounds.width - panelFrame.width) <= 2 && abs(bounds.height - panelFrame.height) <= 2
}
let candidates = windows.filter(matches)
evidence["verifiedPanelWindows"] = candidates
guard candidates.count == 1, let window = candidates.first,
      let id = window[kCGWindowNumber as String] as? NSNumber else {
    finish("BLOCKED: No unique app-owned compositor window matches the verified AX panel")
}
func stillOwned() -> Bool {
    ownedWindows().contains {
        ($0[kCGWindowNumber as String] as? NSNumber) == id && matches($0)
    }
}
guard stillOwned() else { finish("BLOCKED: Native panel ownership changed before capture") }
let name = "native-panel-\(id).png"
let png = directory.appendingPathComponent(name)
let capture = Process()
capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
capture.arguments = ["-x", "-o", "-l", id.stringValue, png.path]
do { try capture.run(); capture.waitUntilExit() }
catch { finish("BLOCKED: Compositor capture failed: \(error)") }
guard capture.terminationStatus == 0, stillOwned(),
      let data = try? Data(contentsOf: png), let bitmap = NSBitmapImageRep(data: data),
      bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 else {
    try? FileManager.default.removeItem(at: png)
    finish("BLOCKED: Native panel capture failed validation or ownership changed")
}
evidence["captures"] = [name]
evidence["nativeCapture"] = name
evidence["status"] = "captured-awaiting-review"
finish("Captured verified app-owned native panel; visual comparison, selected status item and live interaction review remain pending", status: 0)
