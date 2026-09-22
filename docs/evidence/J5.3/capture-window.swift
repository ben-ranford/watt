import AppKit
import CoreGraphics
import ApplicationServices

// Capture only a compositor window independently matched to the fixture's native menu metadata.
// Never request TCC access, cache an NSView, or capture the desktop.
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
    "fixture": "J5.3/base", "node": "30:4788", "processIdentifier": pid,
    "timestampUTC": ISO8601DateFormatter().string(from: Date()),
    "liveInteractionVerified": false, "visualPass": false, "score": NSNull(),
    "pixel_diff": NSNull(), "status": "blocked", "comparableCapture": false,
    "captureAPI": "screencapture -l; independently verified app-owned native menu window only"
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
let metadataURL = directory.appendingPathComponent("capture-attempt.json")
guard let metadataData = try? Data(contentsOf: metadataURL),
      let metadata = (try? JSONSerialization.jsonObject(with: metadataData)) as? [String: Any],
      metadata["fixture"] as? String == "J5.3/base",
      metadata["reference"] as? String == "30:4788",
      (metadata["processIdentifier"] as? NSNumber)?.int32Value == pid,
      let records = metadata["windows"] as? [[String: Any]] else {
    finish("BLOCKED: No matching fixture PID/native-menu identity metadata")
}
let menuIDs = Set(records.compactMap { record -> Int? in
    guard record["class"] as? String == "NSPopupMenuWindow" else { return nil }
    return (record["windowNumber"] as? NSNumber)?.intValue
})
let menus = windows.filter {
    guard let id = ($0[kCGWindowNumber as String] as? NSNumber)?.intValue else { return false }
    return menuIDs.contains(id)
}
evidence["verifiedNativeMenuWindows"] = menus
guard !menus.isEmpty else { finish("BLOCKED: No live app-owned compositor window matches a native NSMenu window") }
var captures: [String] = []
for window in menus {
    guard let id = window[kCGWindowNumber as String] as? NSNumber,
          ownedWindows().contains(where: { ($0[kCGWindowNumber as String] as? NSNumber) == id }) else { continue }
    let name = "native-menu-\(id).png"
    let png = directory.appendingPathComponent(name)
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
        finish("BLOCKED: Native menu capture failed validation or window ownership changed")
    }
    captures.append(name)
}
evidence["captures"] = captures
guard !captures.isEmpty else { finish("BLOCKED: No verified native menu compositor image") }
evidence["status"] = "captured-awaiting-review"
finish("Captured verified app-owned native menu windows; visual comparison and live interaction review remain pending", status: 0)
