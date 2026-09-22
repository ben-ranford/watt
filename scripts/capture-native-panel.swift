import AppKit
import CoreGraphics

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Capture blocked: \(message)\n".utf8))
    exit(1)
}

// Preflight only: never request access or fall back to desktop/AX capture.
guard CGPreflightScreenCaptureAccess() else {
    fail("screen recording access is not already available; no permission requested")
}
if CommandLine.arguments == [CommandLine.arguments[0], "--preflight"] { exit(0) }
guard (3...4).contains(CommandLine.arguments.count),
      let pid = Int32(CommandLine.arguments[1]), pid > 0 else {
    fail("usage: capture-native-panel PID output-directory")
}
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let variant = CommandLine.arguments.count == 4 ? CommandLine.arguments[3] : "panel"
guard ["panel", "light", "dark", "reading-light", "reading-dark", "settings-light", "settings-dark"].contains(variant) else { fail("unknown capture variant") }
let title = variant == "panel" ? "Watt F01 StatusPanel Capture" : "Watt F02 Gallery \(variant)"
func ownedWindows() -> [[String: Any]] {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return windows.filter {
        ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid &&
        $0[kCGWindowName as String] as? String == title &&
        ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
    }
}
var matches: [[String: Any]] = []
for _ in 0..<100 {
    matches = ownedWindows()
    if matches.count == 1 { break }
    Thread.sleep(forTimeInterval: 0.1)
}
guard matches.count == 1, let id = matches[0][kCGWindowNumber as String] as? NSNumber else {
    fail("expected exactly one on-screen capture window owned by PID \(pid)")
}
// Allow the compositor to present after the window becomes discoverable.
Thread.sleep(forTimeInterval: 0.5)
matches = ownedWindows()
guard matches.count == 1,
      (matches.first?[kCGWindowNumber as String] as? NSNumber) == id else {
    fail("owned window changed before capture")
}
let png = output.appendingPathComponent(variant == "panel" ? "status-panel.png" : "gallery-\(variant).png")
let capture = Process()
capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
capture.arguments = ["-x", "-o", "-l", id.stringValue, png.path]
try capture.run()
capture.waitUntilExit()
guard capture.terminationStatus == 0,
      let data = try? Data(contentsOf: png),
      let bitmap = NSBitmapImageRep(data: data), bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 else {
    fail("window-only screencapture failed or PNG could not be decoded")
}
var colors = Set<UInt32>()
for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
    for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        let r = UInt32((color.redComponent * 255).rounded())
        let g = UInt32((color.greenComponent * 255).rounded())
        let b = UInt32((color.blueComponent * 255).rounded())
        colors.insert((r << 16) | (g << 8) | b)
    }
}
let bounds = matches[0][kCGWindowBounds as String] as? [String: Any] ?? [:]
let width = (bounds["Width"] as? NSNumber)?.doubleValue ?? 0
guard width > 0 else { fail("missing window bounds") }
let metadata: [String: Any] = [
    "capturedAtUTC": ISO8601DateFormatter().string(from: Date()),
    "window": matches[0], "pixelWidth": bitmap.pixelsWide, "pixelHeight": bitmap.pixelsHigh,
    "pixelsPerPoint": Double(bitmap.pixelsWide) / width,
    "sampledRGBColors": colors.count, "nonblank": colors.count > 1,
    "appearance": variant.hasSuffix("dark") ? "dark / darkAqua" : "light / aqua", "locale": "en_US",
    "fixture": variant == "panel" ? "PowerReading.sampleCharging" : variant.hasPrefix("reading") ? "J1.2: Delta selected; four enabled options; +42.1 W / 65 W / 22.9 W" : variant.hasPrefix("settings") ? "C05 subset: 580pt; symbol on; smoothing on; section spacing 6pt; title inset 0pt; precision 42.1 W; CPU, GPU; helper On" : "General states: delta selected; components disabled; Icon Only; unselected mini-switch; progress 50%",
    "referenceNode": variant.hasPrefix("reading") ? "27:1354 / window 27:1508 / content 27:1520" : variant.hasPrefix("settings") ? "25:787 / window 25:1102 / content 25:1129" : "general state coverage",
    "confirmationState": "not presented; neutral Remove opens native SwiftUI alert; Cancel role cancel; Remove role destructive; local fixture mutation only; not runtime interaction audited",
    "visualGate": "native smoke capture only; no calibrated Figma comparison or VoiceOver sign-off",
    "capture": "screencapture -x -o -l (app-owned window only)",
    "accessibilityEvidence": "source-native SwiftUI semantics only; no AX traversal, UI automation or VoiceOver audit",
    "osVersion": ProcessInfo.processInfo.operatingSystemVersionString
]
try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("window.json"))
guard colors.count > 1 else { fail("PNG is uniformly blank") }
print("Captured PID \(pid), window \(id): \(bitmap.pixelsWide)x\(bitmap.pixelsHigh), \(colors.count) sampled RGB colors")
