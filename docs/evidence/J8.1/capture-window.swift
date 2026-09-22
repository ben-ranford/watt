import AppKit
import ApplicationServices
import CoreGraphics

// Capture only verified, living fixture PID-owned compositor surfaces.
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
    "fixture": "J8.1/base", "node": "32:3451", "processIdentifier": pid,
    "timestampUTC": ISO8601DateFormatter().string(from: Date()), "windows": windows,
    "screenCapturePreauthorized": permitted, "AXTrusted": trusted,
    "status": "blocked", "visualPass": false, "score": NSNull(), "pixel_diff": NSNull(),
    "comparableCapture": false, "liveInteractionVerified": false,
    "selectedStatusItemVerified": false,
    "captureAPI": "screencapture -l; PID/AX/content/geometry-verified native panel and status item"
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
guard permitted else { finish("BLOCKED: Screen capture not preauthorized; no permission requested") }
guard trusted else { finish("BLOCKED: Accessibility trust unavailable; no permission requested") }
guard !windows.isEmpty else { finish("BLOCKED: No fixture PID-owned on-screen compositor windows") }
guard let data = try? Data(contentsOf: directory.appendingPathComponent("capture-attempt.json")),
      let metadata = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      metadata["fixture"] as? String == "J8.1/base", metadata["node"] as? String == "32:3451",
      (metadata["processIdentifier"] as? NSNumber)?.int32Value == pid,
      metadata["appearance"] as? String == NSAppearance.Name.darkAqua.rawValue,
      metadata["selected"] as? Bool == true, metadata["panelPresented"] as? Bool == true,
      let anchor = metadata["statusItem"] as? [String: Any],
      let anchorID = anchor["windowNumber"] as? NSNumber else {
    finish("BLOCKED: Native PID, dark appearance, selected status item or panel identity unproven")
}
evidence["nativeMetadata"] = metadata
guard let anchorWindow = windows.first(where: { ($0[kCGWindowNumber as String] as? NSNumber) == anchorID }) else {
    finish("BLOCKED: Native status anchor has no fixture PID-owned compositor window")
}
let application = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(application, 1)
var axPID: pid_t = 0
guard AXUIElementGetPid(application, &axPID) == .success, axPID == pid else {
    finish("BLOCKED: AX application identity does not match fixture PID")
}
func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
var elements: [AXUIElement] = []
var records: [[String: Any]] = []
func visit(_ element: AXUIElement, depth: Int = 0) {
    guard depth < 15, elements.count < 400, !elements.contains(where: { CFEqual($0, element) }) else { return }
    elements.append(element)
    var record: [String: Any] = [:]
    for key in ["AXRole", "AXTitle", "AXDescription", "AXValue", "AXSelected", "AXEnabled", "AXIdentifier"] {
        if let value = attribute(element, key), value is String || value is NSNumber { record[key] = value }
    }
    records.append(record)
    for key in ["AXChildren", "AXMenuBar", "AXExtrasMenuBar", "AXWindows"] {
        guard let value = attribute(element, key) else { continue }
        if CFGetTypeID(value) == AXUIElementGetTypeID() {
            visit(unsafeDowncast(value, to: AXUIElement.self), depth: depth + 1)
        } else if let children = value as? [AXUIElement] {
            for child in children { visit(child, depth: depth + 1) }
        }
    }
}
func text(_ records: [[String: Any]]) -> String {
    records.flatMap { $0.values.compactMap { $0 as? String } }.joined(separator: "\n")
}
visit(application)
evidence["AXApplicationPID"] = axPID
evidence["AXElements"] = records
guard records.contains(where: {
    $0["AXRole"] as? String == "AXMenuBarItem" && $0["AXSelected"] as? Bool == true
        && text([$0]).contains("Watt? power reading") && text([$0]).contains("No reading yet")
}) else { finish("BLOCKED: Selected native status item and accessible no-reading value not independently verified") }
evidence["selectedStatusItemVerified"] = true
let axWindows = attribute(application, "AXWindows") as? [AXUIElement] ?? []
let expected = ["No reading", "Usually right after wake. Watt? tries again every few seconds.",
                "Try now", "Try Again", "Settings…", "Quit Watt?"]
var matchingPanels: [AXUIElement] = []
for window in axWindows {
    elements = []; records = []
    visit(window)
    let content = text(records)
    if expected.allSatisfy({ content.contains($0) }),
       !["Components", "Charger input", "System draw"].contains(where: { content.contains($0) }) {
        matchingPanels.append(window)
        evidence["AXPanelElements"] = records
    }
}
guard matchingPanels.count == 1, let panel = matchingPanels.first,
      let pointRef = attribute(panel, "AXPosition"), let sizeRef = attribute(panel, "AXSize"),
      CFGetTypeID(pointRef) == AXValueGetTypeID(), CFGetTypeID(sizeRef) == AXValueGetTypeID() else {
    finish("BLOCKED: No unique live AX panel with exact no-reading content and native controls")
}
var point = CGPoint.zero, size = CGSize.zero
guard AXValueGetValue(pointRef as! AXValue, .cgPoint, &point),
      AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { finish("BLOCKED: Missing live AX panel geometry") }
let panelFrame = CGRect(origin: point, size: size)
evidence["AXPanelFrame"] = ["x": point.x, "y": point.y, "width": size.width, "height": size.height]
evidence["referencePanelFrame"] = ["x": 670, "y": 38, "width": 320, "height": 195]
func bounds(_ window: [String: Any]) -> CGRect? {
    guard let raw = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
    return CGRect(dictionaryRepresentation: raw)
}
let panels = windows.filter {
    guard let frame = bounds($0) else { return false }
    return abs(frame.minX - panelFrame.minX) <= 2 && abs(frame.minY - panelFrame.minY) <= 2
        && abs(frame.width - panelFrame.width) <= 2 && abs(frame.height - panelFrame.height) <= 2
}
guard panels.count == 1, let panelWindow = panels.first else {
    finish("BLOCKED: No unique fixture PID-owned compositor window matches the AX panel")
}
var captures: [String] = []
for (window, name) in [(panelWindow, "native-panel.png"), (anchorWindow, "native-status-anchor.png")] {
    guard let id = window[kCGWindowNumber as String] as? NSNumber else { finish("BLOCKED: Missing compositor ID") }
    func stillOwned() -> Bool {
        kill(pid, 0) == 0 && ownedWindows().contains {
            ($0[kCGWindowNumber as String] as? NSNumber) == id && bounds($0) == bounds(window)
        }
    }
    guard stillOwned() else { finish("BLOCKED: Compositor ownership/geometry changed before capture") }
    let png = directory.appendingPathComponent(name)
    guard !FileManager.default.fileExists(atPath: png.path) else { finish("BLOCKED: Refusing stale capture file") }
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-o", "-l", id.stringValue, png.path]
    do { try capture.run(); capture.waitUntilExit() }
    catch { finish("BLOCKED: Compositor capture failed: \(error)") }
    guard capture.terminationStatus == 0, stillOwned(),
          let data = try? Data(contentsOf: png), let bitmap = NSBitmapImageRep(data: data),
          bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 else {
        try? FileManager.default.removeItem(at: png)
        finish("BLOCKED: Invalid capture or ownership changed")
    }
    captures.append(name)
}
evidence["captures"] = captures
evidence["status"] = "captured-awaiting-review"
evidence["comparableCapture"] = true
finish("Native PID/AX/compositor capture proven; visual/pixel review and live interaction remain pending", status: 0)
