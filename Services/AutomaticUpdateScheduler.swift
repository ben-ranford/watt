import Combine
import Foundation

/// When automatic checks run. Launch is prompt and fixed; later attempts spread out
/// so a fleet does not hit the update host at the same moment.
struct AutomaticUpdateTiming: Equatable, Sendable {
    var launchDelay: TimeInterval
    var interval: TimeInterval
    var jitterFraction: Double
    var initialBackoff: TimeInterval
    var maximumBackoff: TimeInterval
    var busyRetry: TimeInterval
    var minimumDelay: TimeInterval

    static let production = AutomaticUpdateTiming(
        launchDelay: 30,
        interval: 24 * 60 * 60,
        jitterFraction: 0.10,
        initialBackoff: 15 * 60,
        maximumBackoff: 6 * 60 * 60,
        busyRetry: 15 * 60,
        minimumDelay: 0
    )

    /// `unit` is clamped to 0...1. Fraction 0.10 yields 90%...110% of `base`.
    static func scaled(_ base: TimeInterval, fraction: Double, unit: Double, minimum: TimeInterval) -> TimeInterval {
        let clampedUnit = min(1, max(0, unit))
        let clampedFraction = min(1, max(0, fraction))
        let factor = (1 - clampedFraction) + (2 * clampedFraction * clampedUnit)
        return max(minimum, base * factor)
    }
}

@MainActor
protocol UpdateJitter: AnyObject {
    func unit() -> Double
}

@MainActor
final class SystemUpdateJitter: UpdateJitter {
    func unit() -> Double { Double.random(in: 0...1) }
}

@MainActor
protocol UpdateScheduling: AnyObject {
    func schedule(after delay: TimeInterval, perform: @escaping @MainActor () -> Void) -> UUID
    func cancel(_ id: UUID)
}

/// Sleeps on the main actor. A delay of zero still yields, so launch does not block scene setup.
@MainActor
final class TaskUpdateScheduler: UpdateScheduling {
    private var tasks: [UUID: Task<Void, Never>] = [:]

    func schedule(after delay: TimeInterval, perform: @escaping @MainActor () -> Void) -> UUID {
        let id = UUID()
        let seconds = max(0, delay)
        let nanoseconds = seconds >= 86_400 * 365 ? UInt64.max / 2 : UInt64(seconds * 1_000_000_000)
        tasks[id] = Task { @MainActor in
            if nanoseconds > 0 {
                do { try await Task.sleep(nanoseconds: nanoseconds) } catch { return }
            }
            guard !Task.isCancelled else { return }
            self.tasks[id] = nil
            perform()
        }
        return id
    }

    func cancel(_ id: UUID) {
        tasks.removeValue(forKey: id)?.cancel()
    }
}

/// Owns the timer only. The router owns check, download, verification and install.
@MainActor
final class AutomaticUpdateCoordinator {
    private let router: AppRouter
    private let preferences: PreferencesStore
    private let scheduler: any UpdateScheduling
    private let timing: AutomaticUpdateTiming
    private let jitter: any UpdateJitter
    private var token: UUID?
    private var failures = 0
    private var started = false
    private var checkInFlight = false
    private var observation: AnyCancellable?

    init(router: AppRouter, preferences: PreferencesStore, scheduler: any UpdateScheduling,
         timing: AutomaticUpdateTiming = .production, jitter: any UpdateJitter = SystemUpdateJitter()) {
        self.router = router
        self.preferences = preferences
        self.scheduler = scheduler
        self.timing = timing
        self.jitter = jitter
    }

    func start() {
        guard !started else { return }
        started = true
        guard router.canScheduleAutomaticChecks else { return }
        observation = preferences.$checkForUpdatesAutomatically
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.apply(enabled)
            }
    }

    private func apply(_ enabled: Bool) {
        if enabled {
            guard token == nil, !checkInFlight else { return }
            arm(after: timing.launchDelay)
        } else if let token {
            scheduler.cancel(token)
            self.token = nil
        }
    }

    private func arm(after delay: TimeInterval) {
        if let token { scheduler.cancel(token) }
        token = scheduler.schedule(after: delay) { [weak self] in
            self?.token = nil
            self?.runScheduledCheck()
        }
    }

    private func runScheduledCheck() {
        guard preferences.checkForUpdatesAutomatically, !checkInFlight else { return }
        let startedCheck = router.checkForUpdatesInBackground(isEnabled: { [weak self] in
            self?.preferences.checkForUpdatesAutomatically == true
        }, finished: { [weak self] outcome in
            guard let self else { return }
            self.checkInFlight = false
            guard self.preferences.checkForUpdatesAutomatically else { return }
            self.arm(after: self.delay(for: outcome))
        })
        if startedCheck {
            checkInFlight = true
        } else if preferences.checkForUpdatesAutomatically {
            arm(after: scaled(timing.busyRetry))
        }
    }

    private func delay(for outcome: ServiceOutcome<String?>) -> TimeInterval {
        switch outcome {
        case .success:
            failures = 0
            return scaled(timing.interval)
        case .failure(.cancelled):
            return scaled(timing.busyRetry)
        case .failure:
            failures = min(failures + 1, 10)
            let multiplier = pow(2, Double(failures - 1))
            return scaled(min(timing.maximumBackoff, timing.initialBackoff * multiplier))
        }
    }

    private func scaled(_ base: TimeInterval) -> TimeInterval {
        AutomaticUpdateTiming.scaled(base, fraction: timing.jitterFraction, unit: jitter.unit(), minimum: timing.minimumDelay)
    }
}
