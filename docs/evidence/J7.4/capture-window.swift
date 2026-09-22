import AppKit
import ApplicationServices
import CoreGraphics

// Only PID-owned compositor images qualify. No desktop crop or cached NSView fallback.
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
guard kill(pid, 0) == 0 else {
    fputs("Fixture PID is not alive; refusing capture\n", stderr)
    exit(1)
}
let windows = ownedWindows()
let permitted = CGPreflightScreenCaptureAccess()
let trusted = AXIsProcessTrusted()
var evidence: [String: Any] = [
    "fixture": "J7.4/base", "node": "31:7764", "processIdentifier": pid,
    "timestampUTC": ISO8601DateFormatter().string(from: Date()), "windows": windows,
    "screenCapturePreauthorized": permitted, "AXTrusted": trusted,
    "status": "blocked", "visualPass": false, "score": NSNull(), "pixel_diff": NSNull(),
    "comparableCapture": false, "liveInteractionVerified": false,
    "captureAPI": "screencapture -l; independently verified PID-owned status item window"
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
guard let data = try? Data(contentsOf: directory.appendingPathComponent("capture-attempt.json")),
      let metadata = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      metadata["fixture"] as? String == "J7.4/base",
      metadata["reference"] as? String == "31:7764",
      (metadata["processIdentifier"] as? NSNumber)?.int32Value == pid,
      let anchor = metadata["statusItem"] as? [String: Any],
      let anchorID = anchor["windowNumber"] as? NSNumber else {
    finish("BLOCKED: Missing matching native fixture PID/status-anchor metadata")
}
evidence["nativeMetadata"] = metadata
guard metadata["statusText"] as? String == "",
      metadata["symbolName"] as? String == "battery.100percent.bolt",
      metadata["accessibilityReading"] as? String == "+42.1 watts",
      metadata["showsSymbol"] as? Bool == true,
      metadata["selected"] as? Bool == false,
      metadata["appearance"] as? String == NSAppearance.Name.aqua.rawValue else {
    finish("BLOCKED: Native fixture semantics/appearance do not match the idle icon-only Light reference")
}
guard let anchorWindow = windows.first(where: { ($0[kCGWindowNumber as String] as? NSNumber) == anchorID }) else {
    finish("BLOCKED: Status anchor has no independently verified PID-owned compositor window; desktop/foreign-window capture is forbidden")
}
evidence["verifiedStatusItemWindow"] = anchorWindow

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
var axRecords: [[String: Any]] = []
var seen: [AXUIElement] = []
func visit(_ element: AXUIElement, depth: Int) {
    guard depth < 15, seen.count < 400, !seen.contains(where: { CFEqual($0, element) }) else { return }
    seen.append(element)
    var record: [String: Any] = [:]
    for key in ["AXRole", "AXTitle", "AXDescription", "AXSelected", "AXFocused", "AXEnabled", "AXValue"] {
        if let value = attribute(element, key), value is String || value is NSNumber { record[key] = value }
    }
    axRecords.append(record)
    for key in ["AXChildren", "AXMenuBar", "AXExtrasMenuBar", "AXWindows"] {
        guard let value = attribute(element, key) else { continue }
        if CFGetTypeID(value) == AXUIElementGetTypeID() {
            visit(unsafeDowncast(value, to: AXUIElement.self), depth: depth + 1)
        } else if let children = value as? [AXUIElement] {
            for child in children { visit(child, depth: depth + 1) }
        }
    }
}
visit(application, depth: 0)
evidence["AXApplicationPID"] = axPID
evidence["AXElements"] = axRecords
let expectedText = "Watt? power reading"
let expectedValue = "+42.1 watts"
guard axRecords.contains(where: { record in
    ["AXTitle", "AXDescription", "AXValue"].contains { key in
        record[key] as? String == expectedValue
    }
}), axRecords.contains(where: { record in
    ["AXTitle", "AXDescription"].contains { record[$0] as? String == expectedText }
}), axRecords.contains(where: { $0["AXRole"] as? String == "AXMenuBarItem" }) else {
    finish("BLOCKED: PID-owned AX hierarchy does not independently confirm the accessible icon reading and native status item")
}
var captures: [String] = []
for window in [anchorWindow] {
    guard let id = window[kCGWindowNumber as String] as? NSNumber,
          ownedWindows().contains(where: { ($0[kCGWindowNumber as String] as? NSNumber) == id }) else {
        finish("BLOCKED: Compositor ownership changed before capture")
    }
    let name = "native-status-anchor.png"
    let png = directory.appendingPathComponent(name)
    guard !FileManager.default.fileExists(atPath: png.path) else { finish("BLOCKED: Refusing stale capture file") }
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-o", "-l", id.stringValue, png.path]
    do { try capture.run(); capture.waitUntilExit() }
    catch { finish("BLOCKED: Compositor capture failed: \(error)") }
    guard capture.terminationStatus == 0,
          ownedWindows().contains(where: { ($0[kCGWindowNumber as String] as? NSNumber) == id }),
          let data = try? Data(contentsOf: png), let bitmap = NSBitmapImageRep(data: data),
          bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 else {
        try? FileManager.default.removeItem(at: png)
        finish("BLOCKED: Capture invalid or compositor ownership changed")
    }
    captures.append(name)
}
evidence["captures"] = captures
evidence["status"] = "captured-awaiting-review"
evidence["nativeStatusLabelVerified"] = true
finish("Captured PID-owned native status anchor with exact AX reading evidence; icon-only pixels and visual comparison remain pending", status: 0)
