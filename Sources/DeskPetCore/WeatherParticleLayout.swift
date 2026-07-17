import Foundation

public enum WeatherDepth: Int, CaseIterable, Equatable, Sendable {
    case background
    case midground
    case foreground
}

public struct WeatherParticleState: Equatable, Sendable {
    public let x: Double
    public let y: Double
}

public struct WeatherParticleSeed: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let phase: Double
    public let sizeUnit: Double
    public let opacityUnit: Double
    public let blurUnit: Double

    public func state(
        at time: Double,
        speed: Double,
        wind: Double,
        moving: Bool
    ) -> WeatherParticleState {
        let staticState = WeatherParticleState(x: x, y: y)
        guard moving else { return staticState }
        guard time.isFinite, speed.isFinite, wind.isFinite else { return staticState }

        let verticalTravel = time * speed
        guard verticalTravel.isFinite else { return staticState }
        let verticalPosition = y + verticalTravel + phase
        guard verticalPosition.isFinite else { return staticState }
        let animatedY = euclideanModulo(verticalPosition, modulus: 1)
        guard animatedY.isFinite else { return staticState }

        let windOffset = animatedY * wind
        guard windOffset.isFinite else { return staticState }
        let oscillationPhase = time * 0.35 + phase * .pi * 2
        guard oscillationPhase.isFinite else { return staticState }
        let oscillation = sin(oscillationPhase) * 0.015
        guard oscillation.isFinite else { return staticState }
        let horizontalPosition = x + windOffset + oscillation
        guard horizontalPosition.isFinite else { return staticState }
        let animatedX = euclideanModulo(horizontalPosition, modulus: 1)
        guard animatedX.isFinite else { return staticState }

        return WeatherParticleState(x: animatedX, y: animatedY)
    }

    private func euclideanModulo(_ value: Double, modulus: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }
}

public enum WeatherParticleLayout {
    public static func particles(
        count: Int,
        seed: UInt64,
        depth: WeatherDepth
    ) -> [WeatherParticleSeed] {
        guard count > 0 else { return [] }
        var generator = SplitMix64(
            state: seed &+ UInt64(depth.rawValue + 1) &* 0x9E3779B97F4A7C15
        )
        return (0..<count).map { _ in
            WeatherParticleSeed(
                x: generator.nextUnit(),
                y: generator.nextUnit(),
                phase: generator.nextUnit(),
                sizeUnit: generator.nextUnit(),
                opacityUnit: generator.nextUnit(),
                blurUnit: generator.nextUnit()
            )
        }
    }
}

private struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
