import Foundation

public enum PetMotionEvent: String, CaseIterable, Equatable, Sendable {
    case idle
    case walk
    case idleAction1
    case idleAction2
    case lookAround
    case stretch
    case perkUp
}

public struct PetMotionCadence: Equatable, Sendable {
    public let idleDuration: Double
    public let stepsPerSecond: Double
    public let artworkFramesPerSecond: Double
    public let verticalAmplitude: Double
    public let horizontalAmplitude: Double

    public init(
        idleDuration: Double,
        stepsPerSecond: Double,
        artworkFramesPerSecond: Double = 8,
        verticalAmplitude: Double,
        horizontalAmplitude: Double
    ) {
        self.idleDuration = idleDuration
        self.stepsPerSecond = stepsPerSecond
        self.artworkFramesPerSecond = artworkFramesPerSecond
        self.verticalAmplitude = verticalAmplitude
        self.horizontalAmplitude = horizontalAmplitude
    }
}

public struct PetMotionFrame: Equatable, Sendable {
    public let event: PetMotionEvent
    public let artworkFrameIndex: Int?
    public let nextArtworkFrameIndex: Int?
    public let artworkBlend: Double
    public let artworkOpacity: Double
    public let stepCount: Int
    public let eventProgress: Double
    public let horizontalOffset: Double
    public let verticalOffset: Double
    public let tiltDegrees: Double
    public let horizontalScale: Double
    public let verticalScale: Double
    public let shadowScale: Double
    public let shadowOffset: Double

    public var usesEventArtwork: Bool {
        event != .idle && artworkOpacity >= 0.5
    }

    public var presentedArtworkFrameIndex: Int? {
        guard usesEventArtwork else { return nil }
        if artworkBlend >= 0.5, let nextArtworkFrameIndex {
            return nextArtworkFrameIndex
        }
        return artworkFrameIndex
    }

    public init(
        event: PetMotionEvent,
        artworkFrameIndex: Int?,
        nextArtworkFrameIndex: Int? = nil,
        artworkBlend: Double = 0,
        artworkOpacity: Double = 1,
        stepCount: Int,
        eventProgress: Double,
        horizontalOffset: Double,
        verticalOffset: Double,
        tiltDegrees: Double,
        horizontalScale: Double = 1,
        verticalScale: Double = 1,
        shadowScale: Double,
        shadowOffset: Double
    ) {
        self.event = event
        self.artworkFrameIndex = artworkFrameIndex
        self.nextArtworkFrameIndex = nextArtworkFrameIndex
        self.artworkBlend = artworkBlend
        self.artworkOpacity = artworkOpacity
        self.stepCount = stepCount
        self.eventProgress = eventProgress
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.tiltDegrees = tiltDegrees
        self.horizontalScale = horizontalScale
        self.verticalScale = verticalScale
        self.shadowScale = shadowScale
        self.shadowOffset = shadowOffset
    }

    public static let idle = PetMotionFrame(
        event: .idle,
        artworkFrameIndex: nil,
        nextArtworkFrameIndex: nil,
        artworkBlend: 0,
        artworkOpacity: 1,
        stepCount: 0,
        eventProgress: 0,
        horizontalOffset: 0,
        verticalOffset: 0,
        tiltDegrees: 0,
        horizontalScale: 1,
        verticalScale: 1,
        shadowScale: 1,
        shadowOffset: 0
    )
}

public struct PetMotionScheduleClock: Equatable, Sendable {
    public private(set) var origin: Double?
    private var weatherSuspendedElapsed: Double?

    public init(origin: Double? = nil) {
        self.origin = origin?.isFinite == true ? origin : nil
        self.weatherSuspendedElapsed = nil
    }

    public mutating func updateEligibility(_ isEligible: Bool, at time: Double) {
        guard isEligible else {
            origin = nil
            weatherSuspendedElapsed = nil
            return
        }
        guard time.isFinite,
              origin == nil,
              weatherSuspendedElapsed == nil else { return }
        origin = time
    }

    public mutating func suspendForWeather(
        at time: Double,
        preservingElapsed: Bool
    ) {
        guard time.isFinite else { return }
        let elapsedToPreserve = preservingElapsed ? elapsed(at: time) : 0
        origin = nil
        weatherSuspendedElapsed = elapsedToPreserve
    }

    public mutating func resumeAfterWeather(at time: Double) {
        guard time.isFinite else { return }
        let elapsedToRestore = weatherSuspendedElapsed ?? 0
        weatherSuspendedElapsed = nil
        origin = time - elapsedToRestore
    }

    public func elapsed(at time: Double) -> Double {
        guard time.isFinite else { return 0 }
        if let weatherSuspendedElapsed {
            return max(0, weatherSuspendedElapsed)
        }
        guard let origin else { return 0 }
        return max(0, time - origin)
    }
}

public enum PetMotionDirector {
    public static let eventWindowDuration = 4.1

    public static func eventDuration(
        for event: PetMotionEvent,
        pet _: PetKind
    ) -> Double {
        switch event {
        case .idle:
            0
        case .walk:
            0
        case .idleAction1, .idleAction2:
            1.6
        case .lookAround:
            3.2
        case .stretch:
            2.2
        case .perkUp:
            1.8
        }
    }

    public static func cadence(for pet: PetKind, seed: Int) -> PetMotionCadence {
        let idleDuration = 9 + Double(positiveHash(seed, salt: pet.hashSalt) % 14)

        switch pet {
        case .cat:
            return PetMotionCadence(
                idleDuration: idleDuration,
                stepsPerSecond: 1.15,
                artworkFramesPerSecond: 6.9,
                verticalAmplitude: 1.4,
                horizontalAmplitude: 2.2
            )
        case .pauli:
            return PetMotionCadence(
                idleDuration: idleDuration,
                stepsPerSecond: 1.0,
                artworkFramesPerSecond: 6.0,
                verticalAmplitude: 1.0,
                horizontalAmplitude: 1.6
            )
        case .dog:
            return PetMotionCadence(
                idleDuration: idleDuration,
                stepsPerSecond: 1.2,
                artworkFramesPerSecond: 7.2,
                verticalAmplitude: 2.0,
                horizontalAmplitude: 2.6
            )
        }
    }

    public static func frame(
        pet: PetKind,
        time: Double,
        seed: Int,
        isEligible: Bool,
        reduceMotion: Bool
    ) -> PetMotionFrame {
        guard isEligible, !reduceMotion, time.isFinite else { return .idle }

        let cadence = cadence(for: pet, seed: seed)
        let cycleDuration = cadence.idleDuration + eventWindowDuration
        let normalizedTime = euclideanModulo(time, modulus: cycleDuration)
        guard normalizedTime >= cadence.idleDuration else { return .idle }

        let cycleIndex = boundedCycleIndex(for: time, cycleDuration: cycleDuration)
        let eventHash = positiveHash(seed ^ cycleIndex, salt: pet.hashSalt + 101)
        let event: PetMotionEvent = switch eventHash % 11 {
        case 0: .idleAction1
        case 1: .idleAction2
        case 2: .lookAround
        case 3: .stretch
        case 4: .perkUp
        case 5, 6, 7, 8, 9, 10: .walk
        default: .idle
        }
        let elapsed = normalizedTime - cadence.idleDuration

        if event != .walk {
            let duration = eventDuration(for: event, pet: pet)
            guard normalizedTime < cadence.idleDuration + duration else { return .idle }
            let progress = elapsed / duration
            return gestureFrame(event: event, pet: pet, progress: progress)
        }

        let stepCount = 2 + eventHash % 3
        let duration = Double(stepCount) / cadence.stepsPerSecond
        guard normalizedTime < cadence.idleDuration + duration else { return .idle }
        return walkFrame(
            pet: pet,
            cadence: cadence,
            stepCount: stepCount,
            elapsed: elapsed
        )
    }

    public static func previewFrame(
        pet: PetKind,
        event: PetMotionEvent,
        time: Double,
        reduceMotion: Bool
    ) -> PetMotionFrame {
        guard !reduceMotion, time.isFinite else { return .idle }

        switch event {
        case .idle:
            return .idle
        case .walk:
            let cadence = cadence(for: pet, seed: 0)
            let stepCount = 4
            let duration = Double(stepCount) / cadence.stepsPerSecond
            return walkFrame(
                pet: pet,
                cadence: cadence,
                stepCount: stepCount,
                elapsed: euclideanModulo(time, modulus: duration)
            )
        case .idleAction1, .idleAction2, .lookAround, .stretch, .perkUp:
            let duration = eventDuration(for: event, pet: pet)
            return gestureFrame(
                event: event,
                pet: pet,
                progress: euclideanModulo(time, modulus: duration) / duration
            )
        }
    }

    public static func isStrongWeatherReactionActive(
        _ reaction: PetWeatherReaction,
        time: Double
    ) -> Bool {
        guard time.isFinite else { return false }

        let timing: (period: Double, activeFraction: Double)
        switch reaction {
        case .shake:
            timing = (16, 0.08)
        case .startle:
            timing = (22, 0.05)
        case .none, .settle, .headLift, .observe, .shelter,
             .antennaGlow, .visorGlow, .sniff:
            return false
        }
        let phase = euclideanModulo(time, modulus: timing.period) / timing.period
        return phase < timing.activeFraction
    }

    private static func walkFrame(
        pet: PetKind,
        cadence: PetMotionCadence,
        stepCount: Int,
        elapsed: Double
    ) -> PetMotionFrame {
        let duration = Double(stepCount) / cadence.stepsPerSecond
        guard elapsed >= 0, elapsed < duration else { return .idle }
        let progress = elapsed / duration
        let stepProgress = euclideanModulo(
            elapsed * cadence.stepsPerSecond,
            modulus: 1
        )
        let phase = stepProgress * .pi * 2
        let lift = (1 - cos(phase)) * 0.5
        let weightTransfer = sin(phase)
        let startEnvelope = smoothstep(min(1, progress / 0.10))
        let endEnvelope = smoothstep(min(1, (1 - progress) / 0.14))
        let motionEnvelope = min(startEnvelope, endEnvelope)
        let impact = pow(max(0, cos(phase)), 8) * motionEnvelope
        let artworkPosition = stepProgress * 6
        let frameIndex = min(5, Int(artworkPosition))
        let frameProgress = artworkPosition - Double(frameIndex)
        let artworkBlend = smoothstep(
            min(1, max(0, (frameProgress - 0.68) / 0.32))
        )
        let stepIndex = min(stepCount - 1, Int(elapsed * cadence.stepsPerSecond))
        let nextFrameIndex: Int? = if frameIndex < 5 {
            frameIndex + 1
        } else if stepIndex < stepCount - 1 {
            0
        } else {
            nil
        }

        return PetMotionFrame(
            event: .walk,
            artworkFrameIndex: frameIndex,
            nextArtworkFrameIndex: nextFrameIndex,
            artworkBlend: nextFrameIndex == nil ? 0 : artworkBlend,
            artworkOpacity: artworkTransitionOpacity(
                progress: progress,
                fadeInFraction: 0.06,
                fadeOutFraction: 0.08
            ),
            stepCount: stepCount,
            eventProgress: progress,
            horizontalOffset: weightTransfer
                * cadence.horizontalAmplitude
                * 0.62
                * motionEnvelope,
            verticalOffset: -lift * cadence.verticalAmplitude * motionEnvelope,
            tiltDegrees: weightTransfer * pet.walkTiltAmplitude * motionEnvelope,
            horizontalScale: 1 + impact * 0.006 - lift * 0.002 * motionEnvelope,
            verticalScale: 1 - impact * 0.004 + lift * 0.003 * motionEnvelope,
            shadowScale: 1 - lift * 0.09 * motionEnvelope,
            shadowOffset: weightTransfer
                * cadence.horizontalAmplitude
                * 0.28
                * motionEnvelope
        )
    }

    private static func gestureFrame(
        event: PetMotionEvent,
        pet: PetKind,
        progress: Double
    ) -> PetMotionFrame {
        switch event {
        case .idleAction1, .idleAction2:
            return microActionFrame(event: event, pet: pet, progress: progress)
        case .lookAround:
            return lookAroundFrame(pet: pet, progress: progress)
        case .stretch:
            return stretchFrame(pet: pet, progress: progress)
        case .perkUp:
            return perkUpFrame(pet: pet, progress: progress)
        case .idle, .walk:
            return .idle
        }
    }

    private static func microActionFrame(
        event: PetMotionEvent,
        pet: PetKind,
        progress: Double
    ) -> PetMotionFrame {
        let envelope = sin(progress * .pi)
        let direction = event == .idleAction1 ? -1.0 : 1.0

        return PetMotionFrame(
            event: event,
            artworkFrameIndex: nil,
            artworkOpacity: gestureArtworkOpacity(progress: progress),
            stepCount: 0,
            eventProgress: progress,
            horizontalOffset: direction * envelope * pet.microActionOffset,
            verticalOffset: -envelope * pet.microActionLift,
            tiltDegrees: direction * envelope * pet.microActionTilt,
            shadowScale: 1 - envelope * 0.035,
            shadowOffset: direction * envelope * 0.8
        )
    }

    private static func lookAroundFrame(
        pet: PetKind,
        progress: Double
    ) -> PetMotionFrame {
        let scan: Double
        switch progress {
        case ..<0.18:
            scan = -smootherstep(progress / 0.18)
        case ..<0.34:
            scan = -1
        case ..<0.52:
            scan = -1 + smootherstep((progress - 0.34) / 0.18)
        case ..<0.70:
            scan = smootherstep((progress - 0.52) / 0.18) * 0.78
        case ..<0.84:
            scan = 0.78
        default:
            scan = 0.78 * (1 - smootherstep((progress - 0.84) / 0.16))
        }
        let lift = sin(progress * .pi)
        let direction = pet == .cat ? -1.0 : 1.0
        return PetMotionFrame(
            event: .lookAround,
            artworkFrameIndex: nil,
            artworkOpacity: gestureArtworkOpacity(progress: progress),
            stepCount: 0,
            eventProgress: progress,
            horizontalOffset: scan * 0.85,
            verticalOffset: -lift * 0.35,
            tiltDegrees: direction * scan * 1.65,
            horizontalScale: 1 - lift * 0.002,
            verticalScale: 1 + lift * 0.003,
            shadowScale: 1 - lift * 0.018,
            shadowOffset: scan * 0.45
        )
    }

    private static func stretchFrame(
        pet: PetKind,
        progress: Double
    ) -> PetMotionFrame {
        let envelope = sin(progress * .pi)
        let settle = sin(progress * .pi * 2) * envelope
        let direction = pet == .dog ? 1.0 : -1.0
        return PetMotionFrame(
            event: .stretch,
            artworkFrameIndex: nil,
            artworkOpacity: gestureArtworkOpacity(progress: progress),
            stepCount: 0,
            eventProgress: progress,
            horizontalOffset: direction * envelope * 1.0,
            verticalOffset: envelope * 1.2,
            tiltDegrees: direction * envelope * 1.4 + settle * 0.5,
            horizontalScale: 1 + envelope * 0.024,
            verticalScale: 1 - envelope * 0.015,
            shadowScale: 1 + envelope * 0.045,
            shadowOffset: direction * envelope * 0.9
        )
    }

    private static func perkUpFrame(
        pet: PetKind,
        progress: Double
    ) -> PetMotionFrame {
        let envelope = sin(progress * .pi)
        let alertBounce = sin(progress * .pi * 3) * envelope
        let direction = pet == .pauli ? -1.0 : 1.0
        return PetMotionFrame(
            event: .perkUp,
            artworkFrameIndex: nil,
            artworkOpacity: gestureArtworkOpacity(progress: progress),
            stepCount: 0,
            eventProgress: progress,
            horizontalOffset: alertBounce * 0.45,
            verticalOffset: -envelope * 2.1 - abs(alertBounce) * 0.35,
            tiltDegrees: direction * alertBounce * 1.5,
            horizontalScale: 1 - envelope * 0.008,
            verticalScale: 1 + envelope * 0.016,
            shadowScale: 1 - envelope * 0.055,
            shadowOffset: alertBounce * 0.35
        )
    }

    private static func smoothstep(_ value: Double) -> Double {
        let clamped = min(1, max(0, value))
        return clamped * clamped * (3 - 2 * clamped)
    }

    private static func smootherstep(_ value: Double) -> Double {
        let clamped = min(1, max(0, value))
        return clamped * clamped * clamped
            * (clamped * (clamped * 6 - 15) + 10)
    }

    private static func gestureArtworkOpacity(progress: Double) -> Double {
        artworkTransitionOpacity(
            progress: progress,
            fadeInFraction: 0.14,
            fadeOutFraction: 0.18
        )
    }

    private static func artworkTransitionOpacity(
        progress: Double,
        fadeInFraction: Double,
        fadeOutFraction: Double
    ) -> Double {
        let fadeIn = smoothstep(min(1, max(0, progress / fadeInFraction)))
        let fadeOut = smoothstep(
            min(1, max(0, (1 - progress) / fadeOutFraction))
        )
        return min(fadeIn, fadeOut)
    }

    private static func euclideanModulo(_ value: Double, modulus: Double) -> Double {
        guard modulus > 0 else { return 0 }
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }

    private static func boundedCycleIndex(for time: Double, cycleDuration: Double) -> Int {
        let cycleIndexModulus = 9_007_199_254_740_992.0 // 2^53
        let rawCycleIndex = floor(time / cycleDuration)
        let boundedCycleIndex = rawCycleIndex.truncatingRemainder(
            dividingBy: cycleIndexModulus
        )
        return Int(boundedCycleIndex)
    }

    private static func positiveHash(_ value: Int, salt: Int) -> Int {
        var mixed = UInt(bitPattern: value)
        mixed &+= UInt(bitPattern: salt) &* 0x9E3779B185EBCA87
        mixed ^= mixed >> 30
        mixed &*= 0xBF58476D1CE4E5B9
        mixed ^= mixed >> 27
        mixed &*= 0x94D049BB133111EB
        mixed ^= mixed >> 31
        return Int(mixed & UInt(Int.max))
    }
}

private extension PetKind {
    var hashSalt: Int {
        switch self {
        case .cat: 11
        case .pauli: 23
        case .dog: 37
        }
    }

    var walkTiltAmplitude: Double {
        switch self {
        case .cat: 0.8
        case .pauli: 0.45
        case .dog: 1.15
        }
    }

    var microActionOffset: Double {
        switch self {
        case .cat: 1.2
        case .pauli: 0.8
        case .dog: 1.5
        }
    }

    var microActionLift: Double {
        switch self {
        case .cat: 0.7
        case .pauli: 0.4
        case .dog: 1.1
        }
    }

    var microActionTilt: Double {
        switch self {
        case .cat: 1.4
        case .pauli: 0.8
        case .dog: 2.0
        }
    }
}
