import Combine

final class PowerReadingStore: ObservableObject {
    @Published var currentReading: PowerReading

    init(currentReading: PowerReading) {
        self.currentReading = currentReading
    }

    static var preview: PowerReadingStore {
        PowerReadingStore(currentReading: .sampleCharging)
    }
}
