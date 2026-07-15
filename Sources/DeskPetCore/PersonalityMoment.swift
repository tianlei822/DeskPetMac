import Foundation

public enum PersonalityPose: String, CaseIterable, Equatable, Sendable {
    case peek
    case perk
    case stretch
    case proud
}

public enum PersonalityMomentCategory: String, CaseIterable, Equatable, Sendable {
    case general
    case weather
    case focus
    case interaction
}

public struct PersonalityMoment: Identifiable, Equatable, Sendable {
    public let id: String
    public let petKind: PetKind
    public let category: PersonalityMomentCategory
    public let pose: PersonalityPose
    public let line: String
    public let moods: [PetWeatherMood]
    public let minimumWorkProgress: Double?
    public let weight: Int

    public init(
        id: String,
        petKind: PetKind,
        category: PersonalityMomentCategory,
        pose: PersonalityPose,
        line: String,
        moods: [PetWeatherMood] = [],
        minimumWorkProgress: Double? = nil,
        weight: Int = 1
    ) {
        self.id = id
        self.petKind = petKind
        self.category = category
        self.pose = pose
        self.line = line
        self.moods = moods
        self.minimumWorkProgress = minimumWorkProgress
        self.weight = max(1, weight)
    }

    public func matches(_ context: PersonalityMomentContext) -> Bool {
        guard !context.isPresentationBlocked, petKind == context.petKind else { return false }

        if let requestedCategory = context.requestedCategory {
            guard category == requestedCategory else { return false }
        } else if category == .interaction {
            return false
        }

        switch category {
        case .weather:
            return moods.contains(context.mood)
        case .focus:
            return context.workProgress >= (minimumWorkProgress ?? 0)
        case .general, .interaction:
            return true
        }
    }
}

public struct PersonalityMomentContext: Equatable, Sendable {
    public let petKind: PetKind
    public let mood: PetWeatherMood
    public let workProgress: Double
    public let requestedCategory: PersonalityMomentCategory?
    public let isPresentationBlocked: Bool

    public init(
        petKind: PetKind,
        mood: PetWeatherMood,
        workProgress: Double,
        requestedCategory: PersonalityMomentCategory?,
        isPresentationBlocked: Bool
    ) {
        self.petKind = petKind
        self.mood = mood
        self.workProgress = min(1, max(0, workProgress))
        self.requestedCategory = requestedCategory
        self.isPresentationBlocked = isPresentationBlocked
    }
}

public enum PersonalityMomentSelector {
    public static func select(
        from moments: [PersonalityMoment],
        context: PersonalityMomentContext,
        excluding recentIDs: Set<String>,
        roll: Int
    ) -> PersonalityMoment? {
        let candidates = moments.filter {
            !recentIDs.contains($0.id) && $0.matches(context)
        }
        let totalWeight = candidates.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }

        let target = Int(roll.magnitude % UInt(totalWeight))
        var cumulativeWeight = 0
        for moment in candidates {
            cumulativeWeight += moment.weight
            if target < cumulativeWeight {
                return moment
            }
        }

        return candidates.last
    }
}

public enum PersonalityMomentSchedule {
    public static func delay(for roll: Int) -> TimeInterval {
        TimeInterval(600 + Int(roll.magnitude % 601))
    }
}

public enum PersonalityMomentCatalog {
    public static let all: [PersonalityMoment] = [
        .init(
            id: "cat.general.three-pixels",
            petKind: .cat,
            category: .general,
            pose: .stretch,
            line: "I moved three pixels. Exhausting.",
            weight: 3
        ),
        .init(
            id: "cat.general.cursor-supervisor",
            petKind: .cat,
            category: .general,
            pose: .peek,
            line: "I was supervising that cursor.",
            weight: 3
        ),
        .init(
            id: "cat.general.desk-standards",
            petKind: .cat,
            category: .general,
            pose: .proud,
            line: "This desk meets my standards. Barely.",
            weight: 3
        ),
        .init(
            id: "cat.weather.sunbeam",
            petKind: .cat,
            category: .weather,
            pose: .perk,
            line: "A sunbeam has been located. Mine.",
            moods: [.sunny],
            weight: 2
        ),
        .init(
            id: "cat.weather.indoor-planning",
            petKind: .cat,
            category: .weather,
            pose: .proud,
            line: "Wet outside. Excellent indoor planning.",
            moods: [.rainy, .stormy],
            weight: 2
        ),
        .init(
            id: "cat.weather.cozy-plan",
            petKind: .cat,
            category: .weather,
            pose: .stretch,
            line: "Cozy weather. I planned this.",
            moods: [.cloudy, .foggy, .snowy, .cozy],
            weight: 2
        ),
        .init(
            id: "cat.focus.keyboard-guard",
            petKind: .cat,
            category: .focus,
            pose: .perk,
            line: "Your keyboard seems busy. I'll guard it.",
            minimumWorkProgress: 0.25,
            weight: 2
        ),
        .init(
            id: "cat.focus.bold-strategy",
            petKind: .cat,
            category: .focus,
            pose: .peek,
            line: "Still working? Bold strategy.",
            minimumWorkProgress: 0.55,
            weight: 2
        ),
        .init(
            id: "cat.focus.handle-blinking",
            petKind: .cat,
            category: .focus,
            pose: .proud,
            line: "You focus. I'll handle the blinking.",
            minimumWorkProgress: 0.80,
            weight: 2
        ),
        .init(
            id: "cat.interaction.acceptable",
            petKind: .cat,
            category: .interaction,
            pose: .proud,
            line: "Acceptable. You may continue."
        ),
        .init(
            id: "cat.interaction.charming",
            petKind: .cat,
            category: .interaction,
            pose: .perk,
            line: "Yes, yes. I am extremely charming."
        ),
        .init(
            id: "cat.interaction.professional-pat",
            petKind: .cat,
            category: .interaction,
            pose: .stretch,
            line: "That pat was almost professional."
        ),
        .init(
            id: "pauli.general.cursor-patrol",
            petKind: .pauli,
            category: .general,
            pose: .proud,
            line: "Cursor patrol complete. Zero anomalies!",
            weight: 3
        ),
        .init(
            id: "pauli.general.friendly-pixel",
            petKind: .pauli,
            category: .general,
            pose: .peek,
            line: "I found a pixel. It seems friendly.",
            weight: 3
        ),
        .init(
            id: "pauli.general.systems-nominal",
            petKind: .pauli,
            category: .general,
            pose: .perk,
            line: "Desk systems nominal. Spirits excellent.",
            weight: 3
        ),
        .init(
            id: "pauli.weather.solar-reading",
            petKind: .pauli,
            category: .weather,
            pose: .perk,
            line: "Solar reading: delightfully bright.",
            moods: [.sunny],
            weight: 2
        ),
        .init(
            id: "pauli.weather.droplet-count",
            petKind: .pauli,
            category: .weather,
            pose: .peek,
            line: "Droplet count: many. Cozy level: optimal.",
            moods: [.rainy, .stormy],
            weight: 2
        ),
        .init(
            id: "pauli.weather.cloud-scan",
            petKind: .pauli,
            category: .weather,
            pose: .stretch,
            line: "Cloud scan complete. Very fluffy.",
            moods: [.cloudy, .foggy, .snowy, .cozy],
            weight: 2
        ),
        .init(
            id: "pauli.focus.non-zero",
            petKind: .pauli,
            category: .focus,
            pose: .proud,
            line: "Productivity reading: impressively non-zero.",
            minimumWorkProgress: 0.25,
            weight: 2
        ),
        .init(
            id: "pauli.focus.cheering-quietly",
            petKind: .pauli,
            category: .focus,
            pose: .perk,
            line: "Focus streak detected. Cheering quietly.",
            minimumWorkProgress: 0.55,
            weight: 2
        ),
        .init(
            id: "pauli.focus.provide-morale",
            petKind: .pauli,
            category: .focus,
            pose: .proud,
            line: "You compute. I shall provide morale.",
            minimumWorkProgress: 0.80,
            weight: 2
        ),
        .init(
            id: "pauli.interaction.input-received",
            petKind: .pauli,
            category: .interaction,
            pose: .perk,
            line: "Affection input received!"
        ),
        .init(
            id: "pauli.interaction.cache-updated",
            petKind: .pauli,
            category: .interaction,
            pose: .proud,
            line: "Pat confirmed. Friendship cache updated."
        ),
        .init(
            id: "pauli.interaction.testing-protocol",
            petKind: .pauli,
            category: .interaction,
            pose: .stretch,
            line: "Again? Excellent testing protocol."
        )
    ]
}
