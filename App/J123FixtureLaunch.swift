#if DEBUG
import Foundation

/// Controlled no-Watt verification only, not proof of installed-resource removal.
/// WattApp exits before creating any stores, scenes, windows or status items.
enum J123FixtureLaunch {
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J12.3/base"
        }
        return false
        #endif
    }
}
#endif
