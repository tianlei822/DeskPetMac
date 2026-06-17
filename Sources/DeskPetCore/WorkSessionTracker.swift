import Foundation

public struct WorkSessionTracker: Sendable {
    private let activeIdleThreshold: TimeInterval
    private let maxObservationInterval: TimeInterval

    public init(activeIdleThreshold: TimeInterval = 300, maxObservationInterval: TimeInterval = 90) {
        self.activeIdleThreshold = activeIdleThreshold
        self.maxObservationInterval = maxObservationInterval
    }

    public func start(now: Date = Date()) -> WorkSessionState {
        WorkSessionState(activeSeconds: 0, lastObservedAt: now)
    }

    public func recordObservation(
        previous: WorkSessionState,
        now: Date = Date(),
        idleSeconds: TimeInterval
    ) -> WorkSessionState {
        let elapsed = max(0, now.timeIntervalSince(previous.lastObservedAt))
        let increment = idleSeconds <= activeIdleThreshold
            ? Int(min(elapsed, maxObservationInterval))
            : 0

        return WorkSessionState(
            activeSeconds: previous.activeSeconds + increment,
            lastObservedAt: now
        )
    }
}
