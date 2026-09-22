import AppKit
import CoreGraphics
import Foundation
let ax = AXIsProcessTrusted()
let screen = CGPreflightScreenCaptureAccess()
let record: [String: Any] = ["timestampUTC": ISO8601DateFormatter().string(from: Date()), "AXTrusted": ax, "screenCapturePreauthorized": screen, "permissionRequested": false, "implementationCaptureAttempted": false, "runtimeKeyboardVerified": false, "voiceOverVerified": false]
print(String(data: try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
exit(ax && screen ? 0 : 1)
