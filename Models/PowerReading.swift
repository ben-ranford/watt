import Foundation

enum PowerMode: String, CaseIterable, Hashable {
    case charging
    case onBattery
    case charged
    case chargerInput
    case systemDraw
    case perComponent
    case noReading
}

struct PowerReading: Equatable {
    var mode: PowerMode
    var watts: Double?
    var batteryPercentage: Int?
    var detail: String?
    var components: [PowerComponent]

    static let sampleCharging = PowerReading(
        mode: .charging,
        watts: 42.1,
        batteryPercentage: 64,
        detail: "full in about 38 min",
        components: [
            PowerComponent(name: "CPU", watts: 9.8),
            PowerComponent(name: "GPU", watts: 4.1),
            PowerComponent(name: "Display", watts: 5.2),
            PowerComponent(name: "Other", watts: 3.8)
        ]
    )
}

struct PowerComponent: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var watts: Double
}
