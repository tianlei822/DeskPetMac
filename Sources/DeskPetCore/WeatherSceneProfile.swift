import Foundation

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
    public private(set) var background: WeatherDepthProfile
    public private(set) var midground: WeatherDepthProfile
    public private(set) var foreground: WeatherDepthProfile
    public private(set) var wind: Double
    public let showsSplashes: Bool
    public let showsSnowGroundLight: Bool
    public let supportsLightning: Bool
    public let lightningPeriod: Double?
    public let transitionDuration: Double
    public let maximumFramesPerSecond: Double
    public private(set) var precipitationIntensity: Double
    public private(set) var cloudDensity: Double
    public private(set) var fogDensity: Double
    public private(set) var windStrength: Double
    public private(set) var gustStrength: Double
    public private(set) var isDaylight: Bool

    public var totalParticleCount: Int {
        background.count + midground.count + foreground.count
    }

    public init(mood: PetWeatherMood) {
        self.mood = mood
        self.transitionDuration = 0.8
        self.maximumFramesPerSecond = switch mood {
        case .rainy, .snowy, .stormy: 30
        case .sunny, .cloudy, .foggy, .cozy: 24
        }
        self.precipitationIntensity = Self.defaultPrecipitationIntensity(for: mood)
        self.cloudDensity = Self.defaultCloudDensity(for: mood)
        self.fogDensity = mood == .foggy ? 0.68 : 0
        self.windStrength = Self.defaultWindStrength(for: mood)
        self.gustStrength = mood == .stormy ? 0.72 : 0.18
        self.isDaylight = true

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

    public init(mood: PetWeatherMood, details: WeatherDetails) {
        self.init(mood: mood)

        isDaylight = details.isDay ?? true
        cloudDensity = Self.normalized(
            details.cloudCoverPercent,
            divisor: 100,
            fallback: cloudDensity
        )
        windStrength = Self.normalized(
            details.windSpeedKilometersPerHour,
            divisor: 50,
            fallback: windStrength
        )
        gustStrength = Self.normalized(
            details.windGustKilometersPerHour,
            divisor: 70,
            fallback: windStrength * 0.7
        )

        let visibilityFog = details.visibilityMeters.flatMap { visibility -> Double? in
            guard visibility.isFinite else { return nil }
            return 1 - min(1, max(0, (visibility - 300) / 19_700))
        }
        let humidityFog = details.relativeHumidityPercent.flatMap { humidity -> Double? in
            guard humidity.isFinite else { return nil }
            return min(1, max(0, (humidity - 55) / 45))
        }
        if visibilityFog != nil || humidityFog != nil {
            let measuredFog = (visibilityFog ?? 0) * 0.72
                + (humidityFog ?? 0) * 0.28
            fogDensity = mood == .foggy
                ? max(0.30, min(1, measuredFog))
                : min(1, measuredFog * 0.36)
        }

        let precipitation = [
            details.precipitationMillimeters,
            details.rainMillimeters,
            details.snowfallCentimeters.map { $0 * 1.5 },
        ]
            .compactMap(Self.safeNonnegative)
            .max()
        if let precipitation {
            let measured = min(1, precipitation / 4)
            let floor: Double = switch mood {
            case .rainy: 0.18
            case .snowy: 0.20
            case .stormy: 0.48
            case .sunny, .cloudy, .foggy, .cozy: 0
            }
            precipitationIntensity = max(floor, measured)
        }

        if let direction = Self.safeFinite(details.windDirectionDegrees) {
            let radians = direction * .pi / 180
            wind = -sin(radians) * (0.06 + windStrength * 0.30)
        } else {
            wind *= 0.72 + windStrength * 0.56
        }

        guard mood == .rainy || mood == .snowy || mood == .stormy else {
            return
        }
        let targetCount = min(40, max(18, Int(
            (18 + precipitationIntensity * 22).rounded()
        )))
        let baseTotal = max(1, totalParticleCount)
        let countScale = Double(targetCount) / Double(baseTotal)
        let speedScale = 0.72 + precipitationIntensity * 0.58
        let opacityScale = 0.72 + precipitationIntensity * 0.42
        background = Self.scaled(
            background,
            countScale: countScale,
            speedScale: speedScale,
            opacityScale: opacityScale
        )
        midground = Self.scaled(
            midground,
            countScale: countScale,
            speedScale: speedScale,
            opacityScale: opacityScale
        )
        foreground = Self.scaled(
            foreground,
            countScale: countScale,
            speedScale: speedScale,
            opacityScale: opacityScale
        )
        trimParticleBudget(to: 40)
    }

    public init(snapshot: WeatherSnapshot) {
        self.init(mood: snapshot.mood, details: snapshot.details)
    }

    public func renderingMode(reduceMotion: Bool) -> WeatherRenderingMode {
        if reduceMotion {
            return .staticCue
        }
        return switch mood {
        case .sunny, .cozy:
            .staticCue
        case .cloudy, .foggy, .rainy, .snowy, .stormy:
            .animated
        }
    }

    public func framesPerSecond(for depth: WeatherDepth) -> Double {
        switch mood {
        case .sunny, .cloudy, .foggy, .cozy:
            8
        case .rainy, .snowy, .stormy:
            switch depth {
            case .background: 12
            case .midground: 18
            case .foreground: 24
            }
        }
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

    private static func defaultPrecipitationIntensity(
        for mood: PetWeatherMood
    ) -> Double {
        switch mood {
        case .rainy: 0.58
        case .snowy: 0.50
        case .stormy: 0.76
        case .sunny, .cloudy, .foggy, .cozy: 0
        }
    }

    private static func defaultCloudDensity(for mood: PetWeatherMood) -> Double {
        switch mood {
        case .sunny: 0.12
        case .cloudy: 0.72
        case .foggy: 0.82
        case .rainy: 0.86
        case .snowy: 0.78
        case .stormy: 1
        case .cozy: 0.24
        }
    }

    private static func defaultWindStrength(for mood: PetWeatherMood) -> Double {
        switch mood {
        case .stormy: 0.78
        case .rainy, .snowy: 0.48
        case .cloudy, .foggy: 0.28
        case .sunny, .cozy: 0.12
        }
    }

    private static func normalized(
        _ value: Double?,
        divisor: Double,
        fallback: Double
    ) -> Double {
        guard let value = safeFinite(value) else { return fallback }
        return min(1, max(0, value / divisor))
    }

    private static func safeFinite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    private static func safeNonnegative(_ value: Double?) -> Double? {
        guard let value = safeFinite(value) else { return nil }
        return max(0, value)
    }

    private static func scaled(
        _ profile: WeatherDepthProfile,
        countScale: Double,
        speedScale: Double,
        opacityScale: Double
    ) -> WeatherDepthProfile {
        let minimumOpacity = min(
            1,
            profile.opacity.lowerBound * opacityScale
        )
        let maximumOpacity = min(
            1,
            profile.opacity.upperBound * opacityScale
        )
        return WeatherDepthProfile(
            count: max(1, Int((Double(profile.count) * countScale).rounded())),
            speed: profile.speed * speedScale,
            size: profile.size,
            opacity: minimumOpacity...maximumOpacity,
            blur: profile.blur
        )
    }

    private mutating func trimParticleBudget(to limit: Int) {
        var overflow = max(0, totalParticleCount - limit)
        guard overflow > 0 else { return }

        let foregroundReduction = min(overflow, max(0, foreground.count - 1))
        foreground = Self.withCount(
            foreground,
            count: foreground.count - foregroundReduction
        )
        overflow -= foregroundReduction

        let midgroundReduction = min(overflow, max(0, midground.count - 1))
        midground = Self.withCount(
            midground,
            count: midground.count - midgroundReduction
        )
        overflow -= midgroundReduction

        if overflow > 0 {
            background = Self.withCount(
                background,
                count: max(1, background.count - overflow)
            )
        }
    }

    private static func withCount(
        _ profile: WeatherDepthProfile,
        count: Int
    ) -> WeatherDepthProfile {
        WeatherDepthProfile(
            count: count,
            speed: profile.speed,
            size: profile.size,
            opacity: profile.opacity,
            blur: profile.blur
        )
    }
}
