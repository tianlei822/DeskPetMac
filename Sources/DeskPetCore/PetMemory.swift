import Foundation

public enum PetInteractionPreference: String, CaseIterable, Codable, Equatable, Sendable {
    case pat
    case boop
    case scratch
    case swipe
    case nuzzle
    case dance
    case treat
    case toy

    public var displayName: String {
        switch self {
        case .pat:
            "Pats"
        case .boop:
            "Boops"
        case .scratch:
            "Scratches"
        case .swipe:
            "Playful Swipes"
        case .nuzzle:
            "Nuzzles"
        case .dance:
            "Dancing"
        case .treat:
            "Treats"
        case .toy:
            "Toy Time"
        }
    }
}

public enum PetGreeting: Equatable, Sendable {
    case firstMeeting
    case returningSoon
    case welcomeBack
    case longTimeNoSee
}

public struct PetMemory: Codable, Equatable, Sendable {
    public private(set) var bond: PetBond
    public private(set) var lastSeenAt: Date?
    public private(set) var interactionCounts: [String: Int]
    public private(set) var recentMomentIDs: [String]
    public private(set) var dailyRhythm: [Int]
    public private(set) var familiarity: Double
    public private(set) var currentMood: PetWeatherMood
    public private(set) var learnedName: String?

    public init(
        bond: PetBond = PetBond(),
        lastSeenAt: Date? = nil,
        interactionCounts: [String: Int] = [:],
        recentMomentIDs: [String] = [],
        dailyRhythm: [Int] = Array(repeating: 0, count: 24),
        familiarity: Double = 0,
        currentMood: PetWeatherMood = .cozy,
        learnedName: String? = nil
    ) {
        self.bond = bond
        self.lastSeenAt = lastSeenAt
        self.interactionCounts = interactionCounts.mapValues { max(0, $0) }
        self.recentMomentIDs = Array(recentMomentIDs.suffix(6))
        self.dailyRhythm = Self.safeDailyRhythm(dailyRhythm)
        self.familiarity = familiarity.isFinite
            ? min(1, max(0, familiarity))
            : 0
        self.currentMood = currentMood
        self.learnedName = Self.safeName(learnedName)
    }

    public var preferredInteraction: PetInteractionPreference? {
        var preferred: PetInteractionPreference?
        var highestCount = 0
        for interaction in PetInteractionPreference.allCases {
            let count = interactionCounts[interaction.rawValue, default: 0]
            if count > highestCount {
                preferred = interaction
                highestCount = count
            }
        }
        return preferred
    }

    public func rhythmAffinity(atHour hour: Int) -> Double {
        let safeHour = min(23, max(0, hour))
        let total = dailyRhythm.reduce(0, +)
        guard total > 0 else { return 0 }

        let previousHour = (safeHour + 23) % 24
        let nextHour = (safeHour + 1) % 24
        let localWeight = Double(dailyRhythm[safeHour])
            + Double(dailyRhythm[previousHour] + dailyRhythm[nextHour]) * 0.5
        let peak = max(1, dailyRhythm.max() ?? 1)
        let locality = min(1, localWeight / (Double(peak) * 1.5))
        let confidence = min(1, Double(total) / 12)
        return locality * confidence
    }

    public mutating func updateBond(_ bond: PetBond) {
        self.bond = bond
    }

    public mutating func setLearnedName(_ name: String?) {
        learnedName = Self.safeName(name)
    }

    public mutating func recordInteraction(
        _ interaction: PetInteractionPreference,
        at date: Date
    ) {
        interactionCounts[interaction.rawValue, default: 0] += 1
        familiarity = min(1, familiarity + 0.01)
        let hour = Calendar.current.component(.hour, from: date)
        if dailyRhythm.indices.contains(hour) {
            dailyRhythm[hour] += 1
        }
        lastSeenAt = date
    }

    public mutating func recordMoment(_ id: String) {
        guard !id.isEmpty else { return }
        recentMomentIDs.removeAll { $0 == id }
        recentMomentIDs.append(id)
        if recentMomentIDs.count > 6 {
            recentMomentIDs.removeFirst(recentMomentIDs.count - 6)
        }
    }

    public mutating func markSeen(at date: Date, mood: PetWeatherMood) {
        lastSeenAt = date
        currentMood = mood
    }

    public static func greeting(
        lastSeenAt: Date?,
        now: Date
    ) -> PetGreeting {
        guard let lastSeenAt else { return .firstMeeting }
        let secondsApart = max(0, now.timeIntervalSince(lastSeenAt))
        if secondsApart < 6 * 60 * 60 {
            return .returningSoon
        }
        if secondsApart < 7 * 24 * 60 * 60 {
            return .welcomeBack
        }
        return .longTimeNoSee
    }

    private static func safeDailyRhythm(_ values: [Int]) -> [Int] {
        var result = Array(repeating: 0, count: 24)
        for index in result.indices where values.indices.contains(index) {
            result[index] = max(0, values[index])
        }
        return result
    }

    private static func safeName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(24))
    }
}

public struct PetMemoryCollection: Codable, Equatable, Sendable {
    private var storage: [String: PetMemory]

    public init() {
        storage = [:]
    }

    public subscript(petKind: PetKind) -> PetMemory {
        get { storage[petKind.rawValue] ?? PetMemory() }
        set { storage[petKind.rawValue] = newValue }
    }
}
