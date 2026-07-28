import Foundation

/// A short-lived "being carried" lean for the pet while its window is dragged.
public struct PetDragLean: Equatable, Sendable {
    public let tiltDegrees: Double
    public let offsetX: Double
    public let offsetY: Double

    public init(tiltDegrees: Double, offsetX: Double, offsetY: Double) {
        self.tiltDegrees = tiltDegrees
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    public static let neutral = PetDragLean(tiltDegrees: 0, offsetX: 0, offsetY: 0)
}

/// Turns pet-window movement into an inertial lean. Velocities are low-passed
/// while the window moves and decay exponentially once movement stops, so the
/// pet settles back to neutral with a soft finish.
public struct DragLeanTracker: Equatable, Sendable {
    public private(set) var velocityX = 0.0
    public private(set) var velocityY = 0.0
    private var lastX: Double?
    private var lastY: Double?
    private var lastSampleAt: Double?
    private var lastEventAt: Double?

    private static let smoothing = 0.45
    private static let decayRate = 5.5
    private static let maximumRawVelocity = 9_000.0

    public init() {}

    public mutating func recordWindowOrigin(x: Double, y: Double, at time: Double) {
        guard x.isFinite, y.isFinite, time.isFinite else { return }
        if let lastX, let lastY, let lastSampleAt {
            let dt = time - lastSampleAt
            if dt > 0.004 {
                let rawVX = Self.clampVelocity((x - lastX) / dt)
                let rawVY = Self.clampVelocity((y - lastY) / dt)
                velocityX = velocityX * (1 - Self.smoothing) + rawVX * Self.smoothing
                velocityY = velocityY * (1 - Self.smoothing) + rawVY * Self.smoothing
            }
        }
        lastX = x
        lastY = y
        lastSampleAt = time
        lastEventAt = time
    }

    public func lean(at time: Double) -> PetDragLean {
        guard time.isFinite, let lastEventAt else { return .neutral }
        let idle = max(0, time - lastEventAt)
        let decay = exp(-idle * Self.decayRate)
        guard decay > 0.01 else { return .neutral }
        let vx = velocityX * decay
        let vy = velocityY * decay
        guard vx.isFinite, vy.isFinite else { return .neutral }
        return PetDragLean(
            tiltDegrees: Self.clamp(-vx * 0.011, limit: 6.5),
            offsetX: Self.clamp(vx * 0.005, limit: 4),
            offsetY: Self.clamp(vy * 0.0035, limit: 3)
        )
    }

    private static func clampVelocity(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return clamp(value, limit: maximumRawVelocity)
    }

    private static func clamp(_ value: Double, limit: Double) -> Double {
        min(limit, max(-limit, value))
    }
}
