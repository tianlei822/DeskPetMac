public enum PetSoundCue: String, CaseIterable, Equatable, Sendable {
    case pat
    case boop
    case scratch
    case swipe
    case toy
    case treatSatisfied
    case greeting
}

public enum PetSoundPreference {
    public static let defaultEnabled = false
}

public struct PetSoundProfile: Equatable, Sendable {
    public let startFrequency: Double
    public let endFrequency: Double
    public let duration: Double
    public let amplitude: Double
    public let harmonicMix: Double

    public init(
        startFrequency: Double,
        endFrequency: Double,
        duration: Double,
        amplitude: Double,
        harmonicMix: Double
    ) {
        self.startFrequency = Self.clamp(
            startFrequency,
            lower: 120,
            upper: 1_600,
            fallback: 440
        )
        self.endFrequency = Self.clamp(
            endFrequency,
            lower: 120,
            upper: 1_600,
            fallback: 440
        )
        self.duration = Self.clamp(
            duration,
            lower: 0.04,
            upper: 0.22,
            fallback: 0.08
        )
        self.amplitude = Self.clamp(
            amplitude,
            lower: 0.02,
            upper: 0.16,
            fallback: 0.05
        )
        self.harmonicMix = Self.clamp(
            harmonicMix,
            lower: 0,
            upper: 0.5,
            fallback: 0
        )
    }

    private static func clamp(
        _ value: Double,
        lower: Double,
        upper: Double,
        fallback: Double
    ) -> Double {
        guard value.isFinite else { return fallback }
        return min(upper, max(lower, value))
    }
}

public enum PetSoundDesign {
    public static func profile(
        for petKind: PetKind,
        cue: PetSoundCue
    ) -> PetSoundProfile {
        let voice: (base: Double, harmonic: Double) = switch petKind {
        case .cat:
            (520, 0.08)
        case .pauli:
            (760, 0.28)
        case .dog:
            (340, 0.14)
        }

        return switch cue {
        case .pat:
            PetSoundProfile(
                startFrequency: voice.base * 0.82,
                endFrequency: voice.base * 0.92,
                duration: 0.09,
                amplitude: 0.045,
                harmonicMix: voice.harmonic * 0.5
            )
        case .boop:
            PetSoundProfile(
                startFrequency: voice.base,
                endFrequency: voice.base + 180,
                duration: 0.07,
                amplitude: 0.07,
                harmonicMix: voice.harmonic
            )
        case .scratch:
            PetSoundProfile(
                startFrequency: voice.base * 0.95,
                endFrequency: voice.base * 0.74,
                duration: 0.14,
                amplitude: 0.045,
                harmonicMix: voice.harmonic * 0.7
            )
        case .swipe:
            PetSoundProfile(
                startFrequency: voice.base * 1.08,
                endFrequency: voice.base * 0.84,
                duration: 0.08,
                amplitude: 0.04,
                harmonicMix: voice.harmonic * 0.6
            )
        case .toy:
            PetSoundProfile(
                startFrequency: voice.base * 0.84,
                endFrequency: voice.base * 1.10,
                duration: 0.10,
                amplitude: 0.055,
                harmonicMix: voice.harmonic
            )
        case .treatSatisfied:
            PetSoundProfile(
                startFrequency: voice.base * 0.88,
                endFrequency: voice.base * 0.64,
                duration: 0.17,
                amplitude: 0.05,
                harmonicMix: voice.harmonic * 0.55
            )
        case .greeting:
            PetSoundProfile(
                startFrequency: voice.base * 0.76,
                endFrequency: voice.base * 0.96,
                duration: 0.19,
                amplitude: 0.045,
                harmonicMix: voice.harmonic * 0.75
            )
        }
    }
}
