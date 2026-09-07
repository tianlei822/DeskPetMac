import Foundation

/// An exact critically damped spring. Retargeting never resets its velocity.
public struct PetDampedValue: Equatable, Sendable {
    public private(set) var value: Double
    public private(set) var velocity: Double = 0

    public init(value: Double) {
        self.value = value.isFinite ? value : 0
    }

    public mutating func advance(
        toward target: Double,
        deltaTime: Double,
        response: Double = 0.32
    ) {
        guard target.isFinite, deltaTime.isFinite, deltaTime > 0,
              response.isFinite, response > 0 else { return }
        // Do not fast-forward through a suspended/hidden window.
        let dt = min(deltaTime, 0.1)
        let frequency = 4 / response
        let displacement = value - target
        let coefficient = velocity + frequency * displacement
        let decay = exp(-frequency * dt)
        value = target + (displacement + coefficient * dt) * decay
        velocity = (velocity - frequency * coefficient * dt) * decay
    }
}
