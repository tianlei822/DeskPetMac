import Foundation

public enum PetMotionEvent: String, CaseIterable, Equatable, Sendable {
    case idle
    case walk
    case idleAction1
    case idleAction2
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
    public let stepCount: Int
    public let eventProgress: Double
    public let horizontalOffset: Double
    public let verticalOffset: Double
    public let tiltDegrees: Double
    public let shadowScale: Double
    public let shadowOffset: Double

    public init(
        event: PetMotionEvent,
        artworkFrameIndex: Int?,
        stepCount: Int,
        eventProgress: Double,
        horizontalOffset: Double,
        verticalOffset: Double,
        tiltDegrees: Double,
        shadowScale: Double,
        shadowOffset: Double
    ) {
        self.event = event
        self.artworkFrameIndex = artworkFrameIndex
        self.stepCount = stepCount
        self.eventProgress = eventProgress
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.tiltDegrees = tiltDegrees
        self.shadowScale = shadowScale
        self.shadowOffset = shadowOffset
    }

    public static let idle = PetMotionFrame(
        event: .idle,
        artworkFrameIndex: nil,
        stepCount: 0,
        eventProgress: 0,
        horizontalOffset: 0,
        verticalOffset: 0,
        tiltDegrees: 0,
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
    public static func cadence(for pet: PetKind, seed: Int) -> PetMotionCadence {
        let idleDuration = 12 + Double(positiveHash(seed, salt: pet.hashSalt) % 19)

        switch pet {
        case .cat:
            return PetMotionCadence(
                idleDuration: idleDuration,
                stepsPerSecond: 1.55,
                artworkFramesPerSecond: 9.3,
                verticalAmplitude: 1.4,
                horizontalAmplitude: 2.2
            )
        case .pauli:
            return PetMotionCadence(
                idleDuration: idleDuration,
                stepsPerSecond: 1.35,
                artworkFramesPerSecond: 8.1,
                verticalAmplitude: 1.0,
                horizontalAmplitude: 1.6
            )
        case .dog:
            return PetMotionCadence(
                idleDuration: idleDuration,
                stepsPerSecond: 1.65,
                artworkFramesPerSecond: 9.9,
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
        let eventWindow = 3.2
        let cycleDuration = cadence.idleDuration + eventWindow
        let normalizedTime = euclideanModulo(time, modulus: cycleDuration)
        guard normalizedTime >= cadence.idleDuration else { return .idle }

        let cycleIndex = boundedCycleIndex(for: time, cycleDuration: cycleDuration)
        let eventHash = positiveHash(seed ^ cycleIndex, salt: pet.hashSalt + 101)
        let event: PetMotionEvent = switch eventHash % 5 {
        case 0: .idleAction1
        case 1: .idleAction2
        case 2, 3, 4: .walk
        default: .idle
        }
        let elapsed = normalizedTime - cadence.idleDuration

        if event != .walk {
            let duration = 1.6
            guard normalizedTime < cadence.idleDuration + duration else { return .idle }
            let progress = elapsed / duration
            return microActionFrame(event: event, pet: pet, progress: progress)
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
        case .idleAction1, .idleAction2:
            let duration = 1.6
            return microActionFrame(
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
        let settlingDuration = 1 / cadence.artworkFramesPerSecond
        if elapsed >= duration - settlingDuration {
            return PetMotionFrame(
                event: .walk,
                artworkFrameIndex: 5,
                stepCount: stepCount,
                eventProgress: progress,
                horizontalOffset: 0,
                verticalOffset: 0,
                tiltDegrees: 0,
                shadowScale: 1,
                shadowOffset: 0
            )
        }

        let frameIndex = Int(elapsed * cadence.artworkFramesPerSecond) % 6
        let phase = progress * Double(stepCount) * .pi
        let contact = abs(sin(phase))
        let horizontalEnvelope = sin(progress * .pi)

        return PetMotionFrame(
            event: .walk,
            artworkFrameIndex: frameIndex,
            stepCount: stepCount,
            eventProgress: progress,
            horizontalOffset: sin(phase * 0.5) * cadence.horizontalAmplitude * horizontalEnvelope,
            verticalOffset: -contact * cadence.verticalAmplitude,
            tiltDegrees: sin(phase) * pet.walkTiltAmplitude,
            shadowScale: 1 - contact * 0.08,
            shadowOffset: sin(phase) * cadence.horizontalAmplitude * 0.35
        )
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
            stepCount: 0,
            eventProgress: progress,
            horizontalOffset: direction * envelope * pet.microActionOffset,
            verticalOffset: -envelope * pet.microActionLift,
            tiltDegrees: direction * envelope * pet.microActionTilt,
            shadowScale: 1 - envelope * 0.035,
            shadowOffset: direction * envelope * 0.8
        )
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
