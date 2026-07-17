public enum WeatherRenderingMode: Equatable, Sendable {
    case animated
    case staticCue
}

public struct WeatherDepthProfile: Equatable, Sendable {
    public let count: Int
    public let speed: Double
    public let size: ClosedRange<Double>
    public let opacity: ClosedRange<Double>
    public let blur: ClosedRange<Double>

    public init(
        count: Int,
        speed: Double,
        size: ClosedRange<Double>,
        opacity: ClosedRange<Double>,
        blur: ClosedRange<Double>
    ) {
        self.count = count
        self.speed = speed
        self.size = size
        self.opacity = opacity
        self.blur = blur
    }
}

public struct WeatherSceneProfile: Equatable, Sendable {
    public let mood: PetWeatherMood
    public let background: WeatherDepthProfile
    public let midground: WeatherDepthProfile
    public let foreground: WeatherDepthProfile
    public let wind: Double
    public let showsSplashes: Bool
    public let showsSnowGroundLight: Bool
    public let supportsLightning: Bool
    public let lightningPeriod: Double?
    public let transitionDuration: Double
    public let maximumFramesPerSecond: Double

    public var totalParticleCount: Int {
        background.count + midground.count + foreground.count
    }

    public init(mood: PetWeatherMood) {
        self.mood = mood
        self.transitionDuration = 0.8
        self.maximumFramesPerSecond = 30

        switch mood {
        case .sunny:
            background = .init(
                count: 2,
                speed: 0.010,
                size: 1...2,
                opacity: 0.08...0.16,
                blur: 0...0.6
            )
            midground = .init(
                count: 3,
                speed: 0.016,
                size: 1...2.5,
                opacity: 0.10...0.20,
                blur: 0...0.8
            )
            foreground = .init(
                count: 1,
                speed: 0.022,
                size: 2...3,
                opacity: 0.08...0.14,
                blur: 0.5...1.4
            )
            wind = 0.04
            showsSplashes = false
            showsSnowGroundLight = false
            supportsLightning = false
            lightningPeriod = nil
        case .cloudy:
            background = .init(
                count: 0,
                speed: 0,
                size: 0...0,
                opacity: 0...0,
                blur: 0...0
            )
            midground = background
            foreground = background
            wind = 0.08
            showsSplashes = false
            showsSnowGroundLight = false
            supportsLightning = false
            lightningPeriod = nil
        case .foggy:
            background = .init(
                count: 0,
                speed: 0,
                size: 0...0,
                opacity: 0...0,
                blur: 0...0
            )
            midground = background
            foreground = background
            wind = 0.06
            showsSplashes = false
            showsSnowGroundLight = false
            supportsLightning = false
            lightningPeriod = nil
        case .rainy:
            background = .init(
                count: 9,
                speed: 0.28,
                size: 7...11,
                opacity: 0.18...0.30,
                blur: 0...0.4
            )
            midground = .init(
                count: 12,
                speed: 0.40,
                size: 10...15,
                opacity: 0.26...0.42,
                blur: 0...0.8
            )
            foreground = .init(
                count: 11,
                speed: 0.56,
                size: 15...23,
                opacity: 0.34...0.54,
                blur: 0.8...1.8
            )
            wind = -0.16
            showsSplashes = true
            showsSnowGroundLight = false
            supportsLightning = false
            lightningPeriod = nil
        case .snowy:
            background = .init(
                count: 8,
                speed: 0.055,
                size: 2...3,
                opacity: 0.34...0.54,
                blur: 0...0.5
            )
            midground = .init(
                count: 12,
                speed: 0.080,
                size: 3...5,
                opacity: 0.48...0.70,
                blur: 0...0.8
            )
            foreground = .init(
                count: 12,
                speed: 0.105,
                size: 5...8,
                opacity: 0.58...0.82,
                blur: 0.8...2.0
            )
            wind = 0.10
            showsSplashes = false
            showsSnowGroundLight = true
            supportsLightning = false
            lightningPeriod = nil
        case .stormy:
            background = .init(
                count: 7,
                speed: 0.34,
                size: 9...13,
                opacity: 0.20...0.32,
                blur: 0...0.5
            )
            midground = .init(
                count: 10,
                speed: 0.48,
                size: 12...18,
                opacity: 0.30...0.46,
                blur: 0...0.9
            )
            foreground = .init(
                count: 9,
                speed: 0.64,
                size: 17...25,
                opacity: 0.38...0.58,
                blur: 0.8...2.0
            )
            wind = -0.22
            showsSplashes = true
            showsSnowGroundLight = false
            supportsLightning = true
            lightningPeriod = 24
        case .cozy:
            background = .init(
                count: 2,
                speed: 0.006,
                size: 1...2,
                opacity: 0.08...0.14,
                blur: 0...0.8
            )
            midground = .init(
                count: 2,
                speed: 0.010,
                size: 1.5...2.5,
                opacity: 0.09...0.16,
                blur: 0.3...1.0
            )
            foreground = .init(
                count: 1,
                speed: 0.014,
                size: 2...3,
                opacity: 0.07...0.12,
                blur: 0.8...1.6
            )
            wind = 0.02
            showsSplashes = false
            showsSnowGroundLight = false
            supportsLightning = false
            lightningPeriod = nil
        }
    }

    public func renderingMode(reduceMotion: Bool) -> WeatherRenderingMode {
        reduceMotion ? .staticCue : .animated
    }

    public func particleProfile(
        for depth: WeatherDepth,
        reduceMotion: Bool
    ) -> WeatherDepthProfile {
        guard reduceMotion else {
            switch depth {
            case .background: return background
            case .midground: return midground
            case .foreground: return foreground
            }
        }

        guard depth == .midground else {
            return Self.emptyDepthProfile
        }

        switch mood {
        case .rainy, .stormy:
            return .init(
                count: 3,
                speed: 0,
                size: 8...12,
                opacity: 0.10...0.18,
                blur: 0...0.4
            )
        case .snowy:
            return .init(
                count: 3,
                speed: 0,
                size: 2...4,
                opacity: 0.16...0.28,
                blur: 0...0.6
            )
        case .sunny, .cloudy, .foggy, .cozy:
            return Self.emptyDepthProfile
        }
    }

    public func showsGroundFeedback(reduceMotion: Bool) -> Bool {
        !reduceMotion && (showsSplashes || showsSnowGroundLight)
    }

    public static func reaction(
        for pet: PetKind,
        mood: PetWeatherMood
    ) -> PetWeatherReaction {
        switch (pet, mood) {
        case (.cat, .sunny), (.cat, .cloudy), (.cat, .snowy), (.cat, .cozy):
            .settle
        case (.cat, .foggy):
            .observe
        case (.cat, .rainy):
            .shelter
        case (.cat, .stormy):
            .startle
        case (.pauli, .sunny), (.pauli, .foggy), (.pauli, .stormy):
            .antennaGlow
        case (.pauli, .rainy), (.pauli, .snowy):
            .visorGlow
        case (.pauli, .cloudy), (.pauli, .cozy):
            .settle
        case (.dog, .sunny):
            .headLift
        case (.dog, .cloudy), (.dog, .cozy):
            .settle
        case (.dog, .foggy):
            .observe
        case (.dog, .rainy):
            .shake
        case (.dog, .snowy):
            .sniff
        case (.dog, .stormy):
            .startle
        }
    }

    private static let emptyDepthProfile = WeatherDepthProfile(
        count: 0,
        speed: 0,
        size: 0...0,
        opacity: 0...0,
        blur: 0...0
    )
}
