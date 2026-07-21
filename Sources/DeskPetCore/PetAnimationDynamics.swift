import Foundation

public struct PetAnimationPose: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let scale: Double
    public let tiltDegrees: Double

    public init(
        x: Double,
        y: Double,
        scale: Double,
        tiltDegrees: Double
    ) {
        self.x = x
        self.y = y
        self.scale = scale
        self.tiltDegrees = tiltDegrees
    }

    public static let neutral = PetAnimationPose(
        x: 0,
        y: 0,
        scale: 1,
        tiltDegrees: 0
    )
}

public enum PetAnimationDynamics {
    public static let patDuration = 0.56
    public static let danceDuration = 1.8

    public static func idlePose(
        for pet: PetKind,
        time: Double
    ) -> PetAnimationPose {
        guard time.isFinite else { return .neutral }

        let tuning = idleTuning(for: pet)
        let breathPhase = time * tuning.breathFrequency + tuning.phase
        let breath = sin(breathPhase) + sin(breathPhase * 2 - 0.65) * 0.12
        let weightShift = sin(time * tuning.shiftFrequency + tuning.phase * 1.7)
        let secondary = sin(time * tuning.secondaryFrequency + tuning.phase * 0.6)
        let attentionWave = sin(
            time * tuning.shiftFrequency * 0.55 + tuning.phase * 2.2
        )
        let attention = pow(max(0, attentionWave), 6)
        let attentionDirection = sin(
            time * tuning.secondaryFrequency * 0.19 + tuning.phase
        )
        let attentionLift: Double = switch pet {
        case .cat: 0.32
        case .pauli: 0.24
        case .dog: 0.40
        }

        return PetAnimationPose(
            x: weightShift * tuning.horizontalAmplitude,
            y: breath * tuning.verticalAmplitude
                + secondary * tuning.secondaryAmplitude
                - attention * attentionLift,
            scale: 1
                + breath * tuning.scaleAmplitude
                + attention * 0.0008,
            tiltDegrees: weightShift * tuning.tiltAmplitude
                + secondary * 0.12
                + attentionDirection * attention * 0.28
        )
    }

    public static func patPose(
        for pet: PetKind,
        elapsed: Double
    ) -> PetAnimationPose {
        guard elapsed.isFinite, elapsed > 0, elapsed < patDuration else {
            return .neutral
        }

        let progress = elapsed / patDuration
        let lift = pow(sin(progress * .pi), 0.82)
        let settle = sin(progress * .pi * 2) * sin(progress * .pi)
        let direction = pet == .cat ? -1.0 : 1.0
        let energy: Double = switch pet {
        case .cat: 0.88
        case .pauli: 0.72
        case .dog: 1.15
        }

        return PetAnimationPose(
            x: direction * settle * 1.15 * energy,
            y: -lift * 4.2 * energy,
            scale: 1 + lift * 0.035 * energy,
            tiltDegrees: direction * settle * 2.2 * energy
        )
    }

    public static func dancePose(
        for pet: PetKind,
        elapsed: Double
    ) -> PetAnimationPose {
        guard elapsed.isFinite, elapsed > 0, elapsed < danceDuration else {
            return .neutral
        }

        let progress = elapsed / danceDuration
        let envelope = min(
            smoothstep(min(1, progress / 0.14)),
            smoothstep(min(1, (1 - progress) / 0.18))
        )
        let tuning = danceTuning(for: pet)
        let phase = progress * .pi * 2 * tuning.cycles + tuning.phase
        let sway = sin(phase)
        let hop = abs(sin(phase * 0.5))
        let counterMotion = sin(phase * 0.5 + .pi / 3)

        return PetAnimationPose(
            x: sway * tuning.horizontalAmplitude * envelope,
            y: -hop * tuning.verticalAmplitude * envelope,
            scale: 1 + hop * tuning.scaleAmplitude * envelope,
            tiltDegrees: (sway * tuning.tiltAmplitude + counterMotion) * envelope
        )
    }

    public static func isBlinking(
        for pet: PetKind,
        time: Double
    ) -> Bool {
        guard time.isFinite else { return false }

        let timing: (period: Double, phase: Double, duration: Double, doubleEvery: Int) = switch pet {
        case .cat: (4.9, 0.8, 0.13, 3)
        case .pauli: (5.7, 2.1, 0.11, 4)
        case .dog: (4.3, 3.0, 0.15, 3)
        }
        let shiftedTime = time + timing.phase
        let cyclePosition = euclideanModulo(shiftedTime, modulus: timing.period)
        if cyclePosition < timing.duration { return true }

        let cycleIndex = floor(shiftedTime / timing.period)
        let hasDoubleBlink = euclideanModulo(
            cycleIndex,
            modulus: Double(timing.doubleEvery)
        ) == 0
        let secondBlinkStart = timing.duration + 0.16
        return hasDoubleBlink
            && cyclePosition >= secondBlinkStart
            && cyclePosition < secondBlinkStart + timing.duration * 0.82
    }

    public static func tailSwayDegrees(
        for pet: PetKind,
        time: Double,
        isWalking: Bool
    ) -> Double {
        guard time.isFinite else { return 0 }

        let tuning: (frequency: Double, amplitude: Double, phase: Double)
        switch pet {
        case .cat:
            tuning = isWalking ? (2.45, 3.2, 0.7) : (1.18, 2.1, 0.7)
        case .dog:
            tuning = isWalking ? (3.15, 5.2, 2.1) : (1.72, 4.0, 2.1)
        case .pauli:
            return 0
        }

        let primary = sin(time * tuning.frequency + tuning.phase)
        let secondary = sin(
            time * tuning.frequency * 0.53 + tuning.phase * 1.7
        ) * 0.24
        return (primary + secondary) * tuning.amplitude / 1.24
    }

    private static func smoothstep(_ value: Double) -> Double {
        let clamped = min(1, max(0, value))
        return clamped * clamped * (3 - 2 * clamped)
    }

    private static func euclideanModulo(_ value: Double, modulus: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }

    private static func idleTuning(
        for pet: PetKind
    ) -> (
        breathFrequency: Double,
        shiftFrequency: Double,
        secondaryFrequency: Double,
        verticalAmplitude: Double,
        secondaryAmplitude: Double,
        horizontalAmplitude: Double,
        scaleAmplitude: Double,
        tiltAmplitude: Double,
        phase: Double
    ) {
        switch pet {
        case .cat:
            (1.72, 0.47, 2.35, 1.05, 0.22, 0.24, 0.0040, 0.48, 0.7)
        case .pauli:
            (2.18, 0.61, 3.12, 1.18, 0.28, 0.18, 0.0032, 0.34, 1.9)
        case .dog:
            (1.94, 0.72, 2.74, 1.28, 0.34, 0.30, 0.0046, 0.64, 2.8)
        }
    }

    private static func danceTuning(
        for pet: PetKind
    ) -> (
        cycles: Double,
        horizontalAmplitude: Double,
        verticalAmplitude: Double,
        scaleAmplitude: Double,
        tiltAmplitude: Double,
        phase: Double
    ) {
        switch pet {
        case .cat:
            (2.1, 3.8, 5.4, 0.012, 5.4, 0.0)
        case .pauli:
            (2.6, 2.8, 4.2, 0.009, 4.2, .pi / 5)
        case .dog:
            (2.35, 4.6, 7.0, 0.016, 7.2, .pi / 8)
        }
    }
}
