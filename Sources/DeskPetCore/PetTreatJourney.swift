import Foundation

public enum PetTreatPhase: String, CaseIterable, Equatable, Sendable {
    case tossing
    case watching
    case approaching
    case sniffing
    case eating
    case satisfied
    case completed
}

public struct PetTreatJourneyFrame: Equatable, Sendable {
    public let phase: PetTreatPhase
    public let progress: Double
    public let phaseProgress: Double
    public let position: CGPoint
    public let scale: Double
    public let opacity: Double

    public init(
        phase: PetTreatPhase,
        progress: Double,
        phaseProgress: Double,
        position: CGPoint,
        scale: Double,
        opacity: Double
    ) {
        self.phase = phase
        self.progress = progress
        self.phaseProgress = phaseProgress
        self.position = position
        self.scale = scale
        self.opacity = opacity
    }
}

public struct PetTreatJourney: Equatable, Sendable {
    public let start: CGPoint
    public let landing: CGPoint
    public let mouth: CGPoint
    public let duration: TimeInterval

    public init(
        start: CGPoint,
        landing: CGPoint,
        mouth: CGPoint,
        duration: TimeInterval = 3.8
    ) {
        self.start = Self.clamp(start)
        self.landing = Self.clamp(landing)
        self.mouth = Self.clamp(mouth)
        self.duration = duration.isFinite && duration > 0 ? duration : 3.8
    }

    public func frame(at elapsed: TimeInterval) -> PetTreatJourneyFrame {
        let safeElapsed = elapsed.isFinite ? max(0, elapsed) : 0
        let progress = min(1, safeElapsed / duration)

        switch progress {
        case ..<0.22:
            let phaseProgress = progress / 0.22
            let position = tossPosition(at: phaseProgress)
            return frame(
                phase: .tossing,
                progress: progress,
                phaseProgress: phaseProgress,
                position: position,
                scale: 0.82 + sin(phaseProgress * .pi) * 0.18,
                opacity: 1
            )
        case ..<0.35:
            return heldFrame(
                phase: .watching,
                progress: progress,
                lowerBound: 0.22,
                upperBound: 0.35
            )
        case ..<0.55:
            return heldFrame(
                phase: .approaching,
                progress: progress,
                lowerBound: 0.35,
                upperBound: 0.55
            )
        case ..<0.68:
            let phaseProgress = normalized(
                progress,
                lowerBound: 0.55,
                upperBound: 0.68
            )
            let sniff = sin(phaseProgress * .pi * 3) * 0.008
            return frame(
                phase: .sniffing,
                progress: progress,
                phaseProgress: phaseProgress,
                position: CGPoint(x: landing.x + sniff, y: landing.y),
                scale: 0.98,
                opacity: 1
            )
        case ..<0.82:
            let phaseProgress = normalized(
                progress,
                lowerBound: 0.68,
                upperBound: 0.82
            )
            let eased = smoothStep(phaseProgress)
            return frame(
                phase: .eating,
                progress: progress,
                phaseProgress: phaseProgress,
                position: interpolate(from: landing, to: mouth, progress: eased),
                scale: 1 - eased * 0.78,
                opacity: 1 - max(0, eased - 0.72) / 0.28
            )
        case ..<1:
            return frame(
                phase: .satisfied,
                progress: progress,
                phaseProgress: normalized(
                    progress,
                    lowerBound: 0.82,
                    upperBound: 1
                ),
                position: mouth,
                scale: 0.2,
                opacity: 0
            )
        default:
            return frame(
                phase: .completed,
                progress: 1,
                phaseProgress: 1,
                position: mouth,
                scale: 0,
                opacity: 0
            )
        }
    }

    private func tossPosition(at progress: Double) -> CGPoint {
        let linear = interpolate(from: start, to: landing, progress: progress)
        let arc = 0.24 * 4 * progress * (1 - progress)
        return Self.clamp(CGPoint(x: linear.x, y: linear.y - arc))
    }

    private func heldFrame(
        phase: PetTreatPhase,
        progress: Double,
        lowerBound: Double,
        upperBound: Double
    ) -> PetTreatJourneyFrame {
        frame(
            phase: phase,
            progress: progress,
            phaseProgress: normalized(
                progress,
                lowerBound: lowerBound,
                upperBound: upperBound
            ),
            position: landing,
            scale: 1,
            opacity: 1
        )
    }

    private func frame(
        phase: PetTreatPhase,
        progress: Double,
        phaseProgress: Double,
        position: CGPoint,
        scale: Double,
        opacity: Double
    ) -> PetTreatJourneyFrame {
        PetTreatJourneyFrame(
            phase: phase,
            progress: min(1, max(0, progress)),
            phaseProgress: min(1, max(0, phaseProgress)),
            position: Self.clamp(position),
            scale: min(1.2, max(0, scale)),
            opacity: min(1, max(0, opacity))
        )
    }

    private func interpolate(
        from: CGPoint,
        to: CGPoint,
        progress: Double
    ) -> CGPoint {
        CGPoint(
            x: from.x + (to.x - from.x) * progress,
            y: from.y + (to.y - from.y) * progress
        )
    }

    private func normalized(
        _ value: Double,
        lowerBound: Double,
        upperBound: Double
    ) -> Double {
        min(1, max(0, (value - lowerBound) / (upperBound - lowerBound)))
    }

    private func smoothStep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    private static func clamp(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x.isFinite ? min(1, max(0, point.x)) : 0.5,
            y: point.y.isFinite ? min(1, max(0, point.y)) : 0.5
        )
    }
}
