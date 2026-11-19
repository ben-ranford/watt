import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
#endif

#if DEBUG
/// Pure preflight: no store, application, window or service access.
enum WattFixtureLaunchGate {
    static func rejection(arguments: [String]) -> String? {
        #if SWIFT_PACKAGE
        // The package executable deliberately has no dependency on the fixture target.
        guard arguments.contains(where: { $0.hasPrefix("--watt-fixture") }) else { return nil }
        return "Watt fixture launch rejected: \(arguments.dropFirst().joined(separator: " ")). "
            + "Fixture selection requires the native Debug target; gallery smoke uses standalone GalleryHost."
        #else
        do {
            guard let selection = try FixtureLaunchSelection.parse(arguments) else { return nil }
            switch selection {
            case .story:
                _ = try selection.smokeLaunchArguments()
                return nil
            case .gallery(let gallery):
                return "Watt fixture launch rejected: \(gallery.rawValue) must use standalone GalleryHost, not WattApp."
            }
        } catch {
            return "Watt fixture launch rejected: \(arguments.dropFirst().joined(separator: " ")): \(error)"
        }
        #endif
    }
}

#endif
