public enum PetWeatherReaction: String, CaseIterable, Equatable, Sendable {
    case none
    case settle
    case headLift
    case observe
    case shelter
    case antennaGlow
    case visorGlow
    case shake
    case sniff
    case startle
}

public struct WeatherAnimationProfile: Equatable, Sendable {
    public let backgroundParticleCount: Int
    public let foregroundParticleCount: Int
    public let showsGroundRipple: Bool
    public let supportsLightning: Bool
    public let lightningPeriod: Double?
    public let transitionDuration: Double

    public init(mood: PetWeatherMood) {
        self.transitionDuration = 0.6

        switch mood {
        case .sunny:
            self.backgroundParticleCount = 0
            self.foregroundParticleCount = 0
            self.showsGroundRipple = false
            self.supportsLightning = false
            self.lightningPeriod = nil
        case .cloudy:
            self.backgroundParticleCount = 1
            self.foregroundParticleCount = 0
            self.showsGroundRipple = false
            self.supportsLightning = false
            self.lightningPeriod = nil
        case .foggy:
            self.backgroundParticleCount = 1
            self.foregroundParticleCount = 1
            self.showsGroundRipple = false
            self.supportsLightning = false
            self.lightningPeriod = nil
        case .rainy:
            self.backgroundParticleCount = 6
            self.foregroundParticleCount = 6
            self.showsGroundRipple = true
            self.supportsLightning = false
            self.lightningPeriod = nil
        case .snowy:
            self.backgroundParticleCount = 6
            self.foregroundParticleCount = 8
            self.showsGroundRipple = false
            self.supportsLightning = false
            self.lightningPeriod = nil
        case .stormy:
            self.backgroundParticleCount = 4
            self.foregroundParticleCount = 4
            self.showsGroundRipple = true
            self.supportsLightning = true
            self.lightningPeriod = 22
        case .cozy:
            self.backgroundParticleCount = 0
            self.foregroundParticleCount = 0
            self.showsGroundRipple = false
            self.supportsLightning = false
            self.lightningPeriod = nil
        }
    }

    public static func reaction(for petKind: PetKind, mood: PetWeatherMood) -> PetWeatherReaction {
        switch petKind {
        case .cat:
            switch mood {
            case .sunny, .cloudy, .snowy, .cozy:
                .settle
            case .foggy:
                .observe
            case .rainy:
                .shelter
            case .stormy:
                .startle
            }
        case .pauli:
            switch mood {
            case .sunny, .foggy, .stormy:
                .antennaGlow
            case .rainy, .snowy:
                .visorGlow
            case .cloudy, .cozy:
                .settle
            }
        case .dog:
            switch mood {
            case .sunny:
                .headLift
            case .cloudy, .cozy:
                .settle
            case .foggy:
                .observe
            case .rainy:
                .shake
            case .snowy:
                .sniff
            case .stormy:
                .startle
            }
        }
    }
}
