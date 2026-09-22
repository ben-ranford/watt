#if DEBUG
import Foundation

/// Call in app composition BEFORE constructing any live store/service. No side effects.
/// Release does not compile this type; the native target also excludes its source files.
public enum FixtureLaunchSelection: Equatable, Sendable {
    case story(FixtureSelection)
    case gallery(GalleryFixture)

    public static func parse(_ arguments: [String]) throws -> Self? {
        let flags = arguments.filter { $0.hasPrefix("--watt-fixture") }
        guard !flags.isEmpty else { return nil }
        guard flags.count == 1, let index = arguments.firstIndex(of: "--watt-fixture"),
              index + 1 < arguments.count else { throw FixtureError.invalidArguments }
        let value = arguments[index + 1]
        if let gallery = GalleryFixture(rawValue: value) { return .gallery(gallery) }
        let parts = value.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard (1...2).contains(parts.count), !parts.contains("") else { throw FixtureError.invalidArguments }
            if ["J7.2", "J7.3", "J7.4", "J8.1", "J8.2", "J8.3", "J9.1", "J9.2", "J9.3", "J10.1", "J10.2", "J10.3", "J10.4", "J10.5", "J10.6", "J10.7", "J10.8", "J11.1", "J11.2", "J11.3", "J12.1", "J12.2", "J12.3", "J12.4", "J12.5"].contains(parts[0]), value != parts[0] + "/base" { throw FixtureError.invalidArguments }
        return .story(try ScenarioRegistry.resolve(parts[0], variant: parts.count == 2 ? parts[1] : "base"))
    }

    /// Fail closed rather than showing a shell/placeholder for any unimplemented story.
    public func smokeLaunchArguments() throws -> [String] {
        switch self {
        case .gallery(let gallery): return gallery.launchArguments
        case .story(let selection):
            try selection.story.requireRenderTarget()
            if ["C05", "J1.4", "J1.8", "J2.1", "J2.2", "J2.3", "J2.4", "J2.5", "J3.1", "J3.2", "J3.3", "J4.1", "J4.2", "J4.3", "J5.1", "J5.2", "J5.3", "J6.1", "J6.2", "J6.3", "J6.5", "J7.1", "J7.2", "J7.3", "J7.4", "J8.1", "J8.2", "J8.3", "J9.1", "J9.2", "J9.3", "J10.1", "J10.2", "J10.3", "J10.4", "J10.5", "J10.6", "J10.7", "J10.8", "J11.1", "J11.2", "J11.3", "J12.1", "J12.2", "J12.3", "J12.4", "J12.5"].contains(selection.story.id), selection.variant != "base" { throw FixtureError.notImplemented(selection.stableID) }
            if selection.story.id == "J6.4", !["base", "notification-on-authorized", "notification-on-denied", "notification-off-authorized", "notification-off-denied"].contains(selection.variant) { throw FixtureError.notImplemented(selection.stableID) }
            return ["--watt-fixture", selection.stableID]
        }
    }
}
#endif
