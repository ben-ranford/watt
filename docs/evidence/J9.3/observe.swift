import AppKit
import ApplicationServices
import CoreGraphics
let pid = Int32(CommandLine.arguments[1])!
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let windows = (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []).filter {
    ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
}
let record: [String: Any] = [
    "pid": pid, "running": NSRunningApplication(processIdentifier: pid)?.isTerminated == false,
    "ownedWindows": windows, "AXTrusted": AXIsProcessTrusted(),
    "screenCapturePreauthorized": CGPreflightScreenCaptureAccess(),
    "frontmostBundleID": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown",
    "visualPass": false, "score": NSNull(), "pixel_diff": NSNull(),
    "liveInteractionVerified": false,
    "reason": AXIsProcessTrusted() ? "No comparable Finder/system-chrome capture verified" : "AX trust unavailable; no permission requested"
]
try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]).write(to: output)
if CommandLine.arguments.contains("--terminate") {
    print("Native termination request accepted:", NSRunningApplication(processIdentifier: pid)?.terminate() ?? false)
}
