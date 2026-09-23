import AppKit
import CoreGraphics
import ImageIO

func fail(_ message: String) -> Never {
    print("BLOCKED: " + message)
    exit(1)
}
guard CommandLine.arguments.count == 3, let pid = Int32(CommandLine.arguments[1]) else {
    fail("usage: capture-window PID output-directory")
}
guard CGPreflightScreenCaptureAccess() else { fail("Screen capture not preauthorized; no permission requested") }
let directory = URL(fileURLWithPath: CommandLine.arguments[2])
let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []).filter {
        ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid &&
        ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
    }
guard windows.count == 1, let id = windows[0][kCGWindowNumber as String] as? NSNumber else {
    fail("Expected exactly one app-owned on-screen window")
}
let capture = Process()
capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
capture.arguments = ["-x", "-o", "-l", id.stringValue, directory.appendingPathComponent("native-window.png").path]
try capture.run()
capture.waitUntilExit()
guard capture.terminationStatus == 0 else { fail("Window compositor capture failed") }
// The DEBUG NSView.cacheDisplay artifact can be transparent/black for this
// titlebarless SwiftUI host. Preserve a second, app-owned visual crop from the
// compositor capture instead of treating that artifact as visual evidence.
let nativeURL = directory.appendingPathComponent("native-window.png") as CFURL
let contentURL = directory.appendingPathComponent("native-content.png") as CFURL
if let source = CGImageSourceCreateWithURL(nativeURL, nil),
   let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
    let windowBounds = windows[0][kCGWindowBounds as String] as? [String: Any]
    let windowWidth = (windowBounds?["Width"] as? NSNumber)?.doubleValue ?? 480
    let scale = CGFloat(image.width) / CGFloat(max(1, windowWidth))
    let titlebarHeight = Int((32 * scale).rounded())
    let contentHeight = image.height - titlebarHeight
    if contentHeight > 0,
       let content = image.cropping(to: CGRect(x: 0, y: titlebarHeight,
                                                 width: image.width, height: contentHeight)),
       let destination = CGImageDestinationCreateWithURL(contentURL, "public.png" as CFString, 1, nil) {
        CGImageDestinationAddImage(destination, content, nil)
        _ = CGImageDestinationFinalize(destination)
    }
}
try JSONSerialization.data(withJSONObject: [
    "window": windows[0], "fixture": "J1.4/base", "reference": "28:1206",
    "method": "PID-scoped native screencapture; native-content is titlebar crop",
    "nativeContent": "native-content.png", "visualPass": false,
    "limitation": "System notification excluded; AX/VoiceOver and full-frame comparison not performed"
], options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("window.json"))
print("Captured native app-owned J1.4 window")
