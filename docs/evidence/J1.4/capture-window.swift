import AppKit
import CoreGraphics

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
try JSONSerialization.data(withJSONObject: [
    "window": windows[0], "fixture": "J1.4/base", "reference": "28:1206",
    "method": "PID-scoped native screencapture", "visualPass": false,
    "limitation": "Independent visual comparison and AX/VoiceOver audit not performed"
], options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("window.json"))
print("Captured native app-owned J1.4 window")
