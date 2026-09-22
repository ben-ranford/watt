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
let windows = ownedWindows()
let permitted = CGPreflightScreenCaptureAccess()
let trusted = AXIsProcessTrusted()
var evidence: [String: Any] = [
    "fixture": "J7.3/base", "node": "31:7102", "processIdentifier": pid,
    "timestampUTC": ISO8601DateFormatter().string(from: Date()), "windows": windows,
    "screenCapturePreauthorized": permitted, "AXTrusted": trusted,
    "status": "blocked", "visualPass": false, "score": NSNull(), "pixel_diff": NSNull(),
    "comparableCapture": false, "liveInteractionVerified": false,
    "captureAPI": "screencapture -l; independently verified PID-owned Settings and Components popup windows"
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
      metadata["fixture"] as? String == "J7.3/base",
      metadata["reference"] as? String == "31:7102",
      (metadata["processIdentifier"] as? NSNumber)?.int32Value == pid,
      let records = metadata["menuWindows"] as? [[String: Any]],
      let settingsID = metadata["settingsWindowNumber"] as? NSNumber else {
    finish("BLOCKED: Missing matching fixture PID/settings/popup metadata")
}
evidence["nativeMetadata"] = metadata
guard metadata["title"] as? String == "Watt? Settings",
      metadata["appearance"] as? String == NSAppearance.Name.aqua.rawValue,
      metadata["buttonClass"] as? String == "NSPopUpButton",
      metadata["buttonIdentifier"] as? String == "settings.components",
      let items = metadata["items"] as? [[String: Any]],
      items.compactMap({ $0["title"] as? String }) == ["CPU", "GPU", "Display", "SSD", "Other"],
      items.compactMap({ $0["checked"] as? Bool }) == [true, true, false, false, false],
      items.compactMap({ $0["enabled"] as? Bool }) == [true, true, false, false, false] else {
    finish("BLOCKED: Native settings title, appearance or popup state differs from reference")
}
let menuIDs = Set(records.compactMap { record -> Int? in
    guard record["class"] as? String == "NSPopupMenuWindow" else { return nil }
    return (record["windowNumber"] as? NSNumber)?.intValue
})
let menus = windows.filter { menuIDs.contains(($0[kCGWindowNumber as String] as? NSNumber)?.intValue ?? -1) }
evidence["verifiedNativeMenuWindows"] = menus
guard menus.count == 1 else { finish("BLOCKED: Native popup is not independently visible and PID-owned") }
guard let settingsWindow = windows.first(where: { ($0[kCGWindowNumber as String] as? NSNumber) == settingsID }) else {
    finish("BLOCKED: Settings window has no independently verified PID-owned compositor identity")
}
evidence["verifiedSettingsWindow"] = settingsWindow

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
    for key in ["AXRole", "AXTitle", "AXDescription", "AXSelected", "AXFocused", "AXEnabled", "AXMenuItemMarkChar", "AXValue", "AXIdentifier"] {
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
let texts = Set(axRecords.flatMap { record in
    ["AXTitle", "AXDescription", "AXValue"].compactMap { record[$0] as? String }
})
let requiredTexts = ["Watt? Settings", "Menu Bar", "Show", "Components",
                     "Two fit. More crowd the menu bar.", "CPU, GPU", "Precision", "42.1 W"]
guard requiredTexts.allSatisfy(texts.contains),
      axRecords.contains(where: { $0["AXRole"] as? String == "AXPopUpButton"
          && $0["AXIdentifier"] as? String == "settings.components" }) else {
    evidence["AXMissingTexts"] = requiredTexts.filter { !texts.contains($0) }
    finish("BLOCKED: PID-owned AX hierarchy does not confirm settings copy and Components popup")
}
for title in ["CPU", "GPU", "Display", "SSD", "Other"] {
    let selected = title == "CPU" || title == "GPU"
    guard axRecords.contains(where: { record in
        record["AXRole"] as? String == "AXMenuItem" && record["AXTitle"] as? String == title
            && record["AXEnabled"] as? Bool == selected
            && !((record["AXMenuItemMarkChar"] as? String ?? "").isEmpty) == selected
    }) else { finish("BLOCKED: AX does not confirm native checkmark/disabled state for \(title)") }
}
var captures: [String] = []
for window in menus + [settingsWindow] {
    guard let id = window[kCGWindowNumber as String] as? NSNumber,
          ownedWindows().contains(where: { ($0[kCGWindowNumber as String] as? NSNumber) == id }) else {
        finish("BLOCKED: Compositor ownership changed before capture")
    }
    let name = id == settingsID ? "native-settings.png" : "native-menu-\(id).png"
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
evidence["nativeTrackingVerified"] = true
finish("Captured PID-owned Settings and Components popup with AX evidence; visual comparison remains pending", status: 0)
