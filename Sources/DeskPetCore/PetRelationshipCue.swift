import Foundation

public enum PetRelationshipGesture: String, CaseIterable, Equatable, Sendable {
    case inviteTouch
    case leanClose
    case sharedSway
    case anticipatePlay
}

public struct PetRelationshipCue: Equatable, Sendable {
    public let id: String
    public let line: String
    public let pose: PersonalityPose
    public let gesture: PetRelationshipGesture

    public init(
        id: String,
        line: String,
        pose: PersonalityPose,
        gesture: PetRelationshipGesture
    ) {
        self.id = id
        self.line = line
        self.pose = pose
        self.gesture = gesture
    }
}

public struct PetRelationshipCueContext: Equatable, Sendable {
    public let petKind: PetKind
    public let preferredInteraction: PetInteractionPreference?
    public let familiarity: Double
    public let rhythmAffinity: Double
    public let autonomyDrive: PetAutonomyDrive
    public let isPresentationBlocked: Bool

    public init(
        petKind: PetKind,
        preferredInteraction: PetInteractionPreference?,
        familiarity: Double,
        rhythmAffinity: Double,
        autonomyDrive: PetAutonomyDrive,
        isPresentationBlocked: Bool
    ) {
        self.petKind = petKind
        self.preferredInteraction = preferredInteraction
        self.familiarity = Self.clampUnit(familiarity)
        self.rhythmAffinity = Self.clampUnit(rhythmAffinity)
        self.autonomyDrive = autonomyDrive
        self.isPresentationBlocked = isPresentationBlocked
    }

    private static func clampUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}

public enum PetRelationshipCuePlanner {
    public static func cue(
        for context: PetRelationshipCueContext
    ) -> PetRelationshipCue? {
        guard !context.isPresentationBlocked,
              context.autonomyDrive == .seekAttention,
              context.familiarity >= 0.18,
              context.rhythmAffinity >= 0.25
                || context.familiarity >= 0.60,
              let preference = context.preferredInteraction else { return nil }

        return PetRelationshipCue(
            id: "relationship.\(context.petKind.rawValue).\(preference.rawValue)",
            line: line(for: context.petKind, preference: preference),
            pose: pose(for: preference),
            gesture: gesture(for: preference)
        )
    }

    private static func gesture(
        for preference: PetInteractionPreference
    ) -> PetRelationshipGesture {
        switch preference {
        case .pat, .boop, .scratch, .swipe:
            .inviteTouch
        case .nuzzle:
            .leanClose
        case .dance:
            .sharedSway
        case .treat, .toy:
            .anticipatePlay
        }
    }

    private static func pose(
        for preference: PetInteractionPreference
    ) -> PersonalityPose {
        switch preference {
        case .dance:
            .proud
        case .treat, .nuzzle:
            .peek
        case .pat, .boop, .scratch, .swipe, .toy:
            .perk
        }
    }

    private static func line(
        for petKind: PetKind,
        preference: PetInteractionPreference
    ) -> String {
        switch (petKind, preference) {
        case (.cat, .pat):
            "A head pat would be acceptable."
        case (.cat, .boop):
            "One careful nose boop?"
        case (.cat, .scratch):
            "Behind the ears, perhaps?"
        case (.cat, .swipe):
            "The fur could use a playful ruffle."
        case (.cat, .nuzzle):
            "I saved you a warm spot."
        case (.cat, .dance):
            "One tiny dance?"
        case (.cat, .treat):
            "A little fish would suit the moment."
        case (.cat, .toy):
            "The red dot appears to be late."

        case (.pauli, .pat):
            "Pat input is currently welcome."
        case (.pauli, .boop):
            "Sensor boop calibration is ready."
        case (.pauli, .scratch):
            "Temple servo comfort test?"
        case (.pauli, .swipe):
            "Motion-follow routine is standing by."
        case (.pauli, .nuzzle):
            "Companion proximity mode is available."
        case (.pauli, .dance):
            "Shall we run our dance routine?"
        case (.pauli, .treat):
            "A small energy charge would be timely."
        case (.pauli, .toy):
            "Shall I initialize our play node?"

        case (.dog, .pat):
            "A head pat sounds wonderful!"
        case (.dog, .boop):
            "Is this a good time for a boop?"
        case (.dog, .scratch):
            "Could you scratch behind my ears?"
        case (.dog, .swipe):
            "Want to ruffle my fur?"
        case (.dog, .nuzzle):
            "There is room for a cuddle."
        case (.dog, .dance):
            "Maybe one happy dance?"
        case (.dog, .treat):
            "A tiny snack would be lovely."
        case (.dog, .toy):
            "Maybe the ball wants a run?"
        }
    }
}

public enum PetRelationshipGestureMotion {
    public static let duration: TimeInterval = 3.5

    public static func pose(
        for pet: PetKind,
        gesture: PetRelationshipGesture,
        elapsed: TimeInterval,
        reduceMotion: Bool
    ) -> PetAnimationPose {
        guard !reduceMotion,
              elapsed.isFinite,
              elapsed >= 0,
              elapsed < duration else { return .neutral }

        let enter = smoothstep(min(1, elapsed / 0.42))
        let exit = smoothstep(min(1, (duration - elapsed) / 0.55))
        let envelope = min(enter, exit)
        guard envelope > 0 else { return .neutral }

        let tuning = tuning(for: pet)
        switch gesture {
        case .inviteTouch:
            let soften = sin(elapsed * 2.1 + tuning.phase) * 0.25
            return PetAnimationPose(
                x: tuning.direction * (3.4 + soften) * tuning.energy * envelope,
                y: -0.45 * tuning.energy * envelope,
                scale: 1 + 0.008 * tuning.energy * envelope,
                tiltDegrees: tuning.direction
                    * (3.4 + soften) * tuning.energy * envelope
            )
        case .leanClose:
            let breath = sin(elapsed * 2.4 + tuning.phase) * 0.22
            return PetAnimationPose(
                x: tuning.direction * 0.8 * tuning.energy * envelope,
                y: -(2.1 + breath) * tuning.energy * envelope,
                scale: 1 + 0.022 * tuning.energy * envelope,
                tiltDegrees: tuning.direction * 0.9 * tuning.energy * envelope
            )
        case .sharedSway:
            let sway = sin(elapsed * 2.7 + tuning.phase)
            return PetAnimationPose(
                x: sway * 3.1 * tuning.energy * envelope,
                y: -abs(sway) * 0.8 * tuning.energy * envelope,
                scale: 1 + abs(sway) * 0.009 * tuning.energy * envelope,
                tiltDegrees: sway * 3.6 * tuning.energy * envelope
            )
        case .anticipatePlay:
            let perk = 0.45 + abs(sin(elapsed * 3.2 + tuning.phase)) * 0.55
            return PetAnimationPose(
                x: tuning.direction * perk * tuning.energy * envelope,
                y: -perk * 4.1 * tuning.energy * envelope,
                scale: 1 + perk * 0.030 * tuning.energy * envelope,
                tiltDegrees: tuning.direction * perk * 2.5 * tuning.energy * envelope
            )
        }
    }

    private static func tuning(
        for pet: PetKind
    ) -> (energy: Double, direction: Double, phase: Double) {
        switch pet {
        case .cat:
            (0.82, -1, 0.4)
        case .pauli:
            (0.65, 1, 1.2)
        case .dog:
            (1.15, 1, 2.1)
        }
    }

    private static func smoothstep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}
