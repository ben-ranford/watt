import AppKit
import CoreGraphics
import ApplicationServices
func fail(_ message: String) -> Never { print("Capture blocked: \(message)"); exit(1) }
guard CGPreflightScreenCaptureAccess() else { fail("Screen Recording access unavailable; not requested") }
guard CommandLine.arguments.count == 3, let pid = Int32(CommandLine.arguments[1]) else { fail("usage: capture PID output.png") }
var windows: [[String: Any]] = []
for _ in 0..<100 {
    windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []).filter {
        ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid && $0[kCGWindowName as String] as? String == "Watt? Settings"
    }
    if windows.count == 1 { break }
    Thread.sleep(forTimeInterval: 0.1)
}
guard windows.count == 1, let id = windows[0][kCGWindowNumber as String] as? NSNumber else { fail("Expected one app-owned native Settings window") }
Thread.sleep(forTimeInterval: 1)
let capture = Process()
capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
capture.arguments = ["-x", "-o", "-l", id.stringValue, CommandLine.arguments[2]]
try capture.run(); capture.waitUntilExit()
guard capture.terminationStatus == 0 else { fail("window capture failed") }
print("Native Settings window captured. AX trusted: \(AXIsProcessTrusted()). No AX audit or live helper/system approval evidence.")
print(windows[0])
