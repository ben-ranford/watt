import Combine
import Foundation

enum WattDisplayMode: String, CaseIterable, Hashable {
    case delta = "Delta"
    case charger = "Charger"
    case draw = "Draw"
    case components = "Components"
    case iconOnly = "Icon Only"
}

final class PreferencesStore: ObservableObject {
    @Published var displayMode: WattDisplayMode = .delta
    @Published var showSymbol = true
    @Published var updateInterval = "Every 2 seconds"
    @Published var smoothReadings = true
    @Published var componentReadings = true
    @Published var chargerNotification = true
    @Published var fullyChargedNotification = false
    @Published var openAtLogin = true
    @Published var checkForUpdatesAutomatically = true
    @Published var selectedComponents = ["CPU", "GPU"]

    static var preview: PreferencesStore {
        PreferencesStore()
    }
}
