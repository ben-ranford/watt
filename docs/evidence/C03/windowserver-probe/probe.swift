// Compile-only API availability probe. Never captures a desktop or other app.
import AppKit

@MainActor
func captureOwnedPopup(_ window: NSWindow) -> CGImage? {
    guard window.isVisible,
          String(describing: type(of: window)) == "NSPopupMenuWindow",
          window.windowNumber > 0 else { return nil }
    let id = CGWindowID(window.windowNumber)
    guard let entries = CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]],
          entries.count == 1,
          let entry = entries.first,
          (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == ProcessInfo.processInfo.processIdentifier,
          (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id else { return nil }
    return CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution])
}
