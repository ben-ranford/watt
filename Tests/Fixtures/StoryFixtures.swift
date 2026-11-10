#if DEBUG || SWIFT_PACKAGE
import Foundation

public enum FixtureError: Error, Equatable {
    case unknownID(String), unknownVariant(String), notImplemented(String), invalidArguments
}

public struct StoryFixture: Codable, Equatable, Sendable {
    public let id: String
    public let node: String
    public let frame: String
    public let state: String
    public let navigation: String
    public let expectedScene: String
    public let appearance: String?
    /// Stable scenario identity recorded with each fixture.
    public let referenceJSON: String
    public let variants: [String]
    public let acceptance: String
    public var status: String { ["C01", "C02", "C03", "C04.1", "C04.2", "C04.3", "C04.4", "C04.5", "C04.6", "C04.7", "C04.8", "C04.9", "C04.10", "C04.11", "C04.12", "C05", "J1.1", "J1.2", "J1.3", "J1.4", "J1.5", "J1.6", "J1.7", "J1.8", "J2.1", "J2.2", "J2.3", "J2.4", "J2.5", "J3.1", "J3.2", "J3.3", "J4.1", "J4.2", "J4.3", "J5.1", "J5.2", "J5.3", "J6.1", "J6.2", "J6.3", "J6.4", "J6.5", "J7.1", "J7.2", "J7.3", "J7.4", "J8.1", "J8.2", "J8.3", "J9.1", "J9.2", "J9.3", "J10.2", "J10.3", "J10.4", "J10.5", "J10.6", "J10.7", "J10.8", "J11.1", "J11.2", "J11.3", "J12.1", "J12.2", "J12.3", "J12.4", "J12.5"].contains(id) ? "implemented" : "not implemented" }
    public var fixedClock: Date { Date(timeIntervalSince1970: 1_789_862_400) }
    public var componentIDs: [String] { ["cpu", "gpu", "display", "other"] }
    public var storagePolicy: String { "fresh in-memory instance per launch; no UserDefaults" }
    public var fakeOutcomePolicy: String { id == "J10.8" ? "DEBUG-only helper update after verified relaunch; isolated approval reply, no helper/OS mutation" : id == "J10.7" ? "Debug-only injected network failure; native NSAlert and scoped retry, no network effects" : id == "J10.6" ? "Debug-only injected nil check; persisted idle then native OS alert, no network/install effects" : id == "J10.5" ? "Debug-only exact staged receipt; scoped intents only, no install/relaunch/helper effects" : id == "J10.4" ? "Debug-only 50% byte progress through injected suspended service; no network/install/relaunch effects" : id == "J10.3" ? "Debug-only injected 1.1 offer; version-scoped intents only, no download/install/helper effects" : id == "J10.2" ? "Suspended Debug-only check; no fabricated result or external effects" : id == "J10.1" ? "No production updater composition; render launch remains closed; injected UpdateService outcomes only in unit tests" : id == "J9.3" ? "native process termination via production Quit action; isolated stores; no simulated exit success" : "scripted only; no hardware, network, polling, prompts or OS effects" }
    public func requireRenderTarget() throws {
        guard ["C01", "C02", "C03", "C04.1", "C04.2", "C04.3", "C04.4", "C04.5", "C04.6", "C04.7", "C04.8", "C04.9", "C04.10", "C04.11", "C04.12", "C05", "J1.1", "J1.2", "J1.3", "J1.4", "J1.5", "J1.6", "J1.7", "J1.8", "J2.1", "J2.2", "J2.3", "J2.4", "J2.5", "J3.1", "J3.2", "J3.3", "J4.1", "J4.2", "J4.3", "J5.1", "J5.2", "J5.3", "J6.1", "J6.2", "J6.3", "J6.4", "J6.5", "J7.1", "J7.2", "J7.3", "J7.4", "J8.1", "J8.2", "J8.3", "J9.1", "J9.2", "J9.3", "J10.2", "J10.3", "J10.4", "J10.5", "J10.6", "J10.7", "J10.8", "J11.1", "J11.2", "J11.3", "J12.1", "J12.2", "J12.3", "J12.4", "J12.5"].contains(id) else { throw FixtureError.notImplemented(id) }
    }
}

/// Value storage: copies never share state, and no filesystem/preferences APIs are called.
public struct FixtureStorage: Equatable, Sendable {
    public var values: [String: Data] = [:]
    public init() {}
}

public struct FixtureSelection: Equatable, Sendable {
    public let story: StoryFixture
    public let variant: String
    public var stableID: String { story.id + "/" + variant }
    public var scriptedOutcome: String { variant == "base" ? story.state : variant }
    public func makeStorage() -> FixtureStorage { FixtureStorage() }
}

public enum ScenarioRegistry {
    public static let stories = StoryFixtureData.stories
    public static func resolve(_ id: String, variant: String = "base") throws -> FixtureSelection {
        guard let story = stories.first(where: { $0.id == id }) else { throw FixtureError.unknownID(id) }
        guard story.variants.contains(variant) else { throw FixtureError.unknownVariant(variant) }
        return FixtureSelection(story: story, variant: variant)
    }
    public static func canonicalData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(stories)
    }
}

/// Smoke targets are never story IDs and never assert story implementation.
public enum GalleryFixture: String, CaseIterable, Sendable {
    case light = "F02.gallery.light", dark = "F02.gallery.dark"
    public var appearance: String { self == .light ? "light" : "dark" }
    public var launchArguments: [String] { ["--watt-capture-gallery-" + appearance] }
    public var windowTitle: String { "Watt F02 Gallery " + appearance }
}
#endif
