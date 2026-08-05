import Foundation

public enum PetAutonomyDrive: String, CaseIterable, Equatable, Sendable {
    case rest
    case explore
    case selfCare
    case observeWeather
    case seekAttention
    case encourageBreak

    public var activityLabel: String {
        switch self {
        case .rest: "Resting"
        case .explore: "Exploring"
        case .selfCare: "Self-care"
        case .observeWeather: "Watching the weather"
        case .seekAttention: "Looking for you"
        case .encourageBreak: "Stretching with you"
        }
    }
}

public struct PetAutonomyState: Equatable, Sendable {
    public let energy: Double
    public let curiosity: Double
    public let socialNeed: Double
    public let focusPressure: Double
    public let weatherInterest: Double
    public let dominantDrive: PetAutonomyDrive
    public let familiarity: Double
    public let preferredInteraction: PetInteractionPreference?
    public let rhythmAffinity: Double

    public init(
        energy: Double,
        curiosity: Double,
        socialNeed: Double,
        focusPressure: Double,
        weatherInterest: Double,
        dominantDrive: PetAutonomyDrive,
        familiarity: Double = 0,
        preferredInteraction: PetInteractionPreference? = nil,
        rhythmAffinity: Double = 0
    ) {
        self.energy = Self.clampUnit(energy)
        self.curiosity = Self.clampUnit(curiosity)
        self.socialNeed = Self.clampUnit(socialNeed)
        self.focusPressure = Self.clampUnit(focusPressure)
        self.weatherInterest = Self.clampUnit(weatherInterest)
        self.dominantDrive = dominantDrive
        self.familiarity = Self.clampUnit(familiarity)
        self.preferredInteraction = preferredInteraction
        self.rhythmAffinity = Self.clampUnit(rhythmAffinity)
    }

    public static let neutral = PetAutonomyState(
        energy: 0.6,
        curiosity: 0.5,
        socialNeed: 0.3,
        focusPressure: 0,
        weatherInterest: 0.3,
        dominantDrive: .selfCare
    )

    private static func clampUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}

public enum PetAutonomyDirector {
    public static func state(
        pet: PetKind,
        hourOfDay: Int,
        secondsSinceInteraction: Double,
        workProgress: Double,
        mood: PetWeatherMood,
        bondProgress: Double,
        familiarity: Double = 0,
        preferredInteraction: PetInteractionPreference? = nil,
        rhythmAffinity: Double = 0
    ) -> PetAutonomyState {
        let hour = min(23, max(0, hourOfDay))
        let quietSeconds = safeNonnegative(secondsSinceInteraction)
        let focus = clampUnit(workProgress)
        let bond = clampUnit(bondProgress)
        let familiarity = clampUnit(familiarity)
        let rhythmAffinity = clampUnit(rhythmAffinity)
        let daylightPhase = sin(
            (Double(hour) - 6) / 16 * .pi
        )
        let circadianEnergy = 0.24 + max(0, daylightPhase) * 0.72
        let weatherEnergyPenalty: Double = switch mood {
        case .stormy: 0.13
        case .rainy, .snowy, .cozy: 0.07
        case .sunny, .cloudy, .foggy: 0
        }
        let energy = clampUnit(
            circadianEnergy - weatherEnergyPenalty + rhythmAffinity * 0.03
        )

        let quietProgress = min(1, quietSeconds / (20 * 60))
        let socialBias: Double = switch pet {
        case .cat: -0.04
        case .pauli: 0.04
        case .dog: 0.12
        }
        let socialNeed = clampUnit(
            0.10 + quietProgress * 0.72 + socialBias + bond * 0.08
                + familiarity * 0.08 + rhythmAffinity * 0.10
        )

        let curiosityBias: Double = switch pet {
        case .cat: 0.14
        case .pauli: 0.18
        case .dog: 0.10
        }
        let curiosity = clampUnit(
            0.30 + curiosityBias + energy * 0.18 + quietProgress * 0.16
                - focus * 0.08 + familiarity * 0.04
        )
        let weatherInterest: Double = switch mood {
        case .stormy: 0.96
        case .snowy: 0.88
        case .foggy: 0.78
        case .rainy: 0.70
        case .sunny: 0.62
        case .cloudy: 0.44
        case .cozy: 0.24
        }

        let drive: PetAutonomyDrive
        if energy < 0.34 {
            drive = .rest
        } else if focus >= 0.85 {
            drive = .encourageBreak
        } else if socialNeed >= 0.72 {
            drive = .seekAttention
        } else if weatherInterest >= 0.76 {
            drive = .observeWeather
        } else if curiosity >= 0.58 {
            drive = .explore
        } else {
            drive = .selfCare
        }

        return PetAutonomyState(
            energy: energy,
            curiosity: curiosity,
            socialNeed: socialNeed,
            focusPressure: focus,
            weatherInterest: weatherInterest,
            dominantDrive: drive,
            familiarity: familiarity,
            preferredInteraction: preferredInteraction,
            rhythmAffinity: rhythmAffinity
        )
    }

    public static func event(
        for pet: PetKind,
        state: PetAutonomyState,
        roll: Int
    ) -> PetMotionEvent {
        var events: [PetMotionEvent] = switch (pet, state.dominantDrive) {
        case (.cat, .rest): [.idleAction1, .stretch]
        case (.pauli, .rest): [.idleAction2, .idleAction1]
        case (.dog, .rest): [.stretch, .idleAction1]
        case (.cat, .explore): [.walk, .lookAround, .walk, .perkUp]
        case (.pauli, .explore): [.lookAround, .walk, .idleAction2, .walk]
        case (.dog, .explore): [.walk, .perkUp, .walk, .lookAround]
        case (.cat, .selfCare): [.idleAction1, .stretch, .idleAction1]
        case (.pauli, .selfCare): [.idleAction2, .idleAction1, .stretch]
        case (.dog, .selfCare): [.idleAction1, .stretch, .idleAction2]
        case (.cat, .observeWeather): [.lookAround, .perkUp, .lookAround]
        case (.pauli, .observeWeather): [.lookAround, .idleAction2, .perkUp]
        case (.dog, .observeWeather): [.perkUp, .lookAround, .idleAction2]
        case (.cat, .seekAttention): [.perkUp, .lookAround, .idleAction2]
        case (.pauli, .seekAttention): [.perkUp, .idleAction2, .lookAround]
        case (.dog, .seekAttention): [.perkUp, .walk, .idleAction2]
        case (_, .encourageBreak): [.stretch, .perkUp, .stretch]
        }
        if state.dominantDrive == .seekAttention,
           let preferredEvent = attentionEvent(
               for: state.preferredInteraction
           ) {
            events.removeAll { $0 == preferredEvent }
            events.insert(preferredEvent, at: 0)
        }
        let index = Int(roll.magnitude % UInt(events.count))
        return events[index]
    }

    public static func idleDuration(
        base: Double,
        state: PetAutonomyState
    ) -> Double {
        let safeBase = base.isFinite ? base : 18
        let multiplier: Double = switch state.dominantDrive {
        case .rest: 1.25
        case .explore: 0.70
        case .selfCare: 1.0
        case .observeWeather: 0.82
        case .seekAttention: 0.64
        case .encourageBreak: 0.76
        }
        return min(30, max(8, safeBase * multiplier))
    }

    private static func safeNonnegative(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(0, value)
    }

    private static func attentionEvent(
        for preference: PetInteractionPreference?
    ) -> PetMotionEvent? {
        switch preference {
        case .pat, .boop, .scratch, .nuzzle:
            .perkUp
        case .swipe:
            .idleAction1
        case .dance:
            .idleAction2
        case .treat:
            .lookAround
        case .toy:
            .walk
        case nil:
            nil
        }
    }

    private static func clampUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}
