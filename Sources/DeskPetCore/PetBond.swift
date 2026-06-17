import Foundation

/// Tracks how attached the pet has grown through interaction. Persisted across launches.
public struct PetBond: Equatable, Codable, Sendable {
    public var points: Int
    public var totalPats: Int

    public init(points: Int = 0, totalPats: Int = 0) {
        self.points = max(0, points)
        self.totalPats = max(0, totalPats)
    }

    /// Adds affection for a single pat. `comboMultiplier` rewards rapid pat streaks
    /// while staying clamped so the bond can't balloon from one frantic burst.
    public mutating func registerPat(comboMultiplier: Int = 1) {
        let multiplier = min(max(comboMultiplier, 1), 5)
        points += multiplier
        totalPats += 1
    }

    /// Adds a small affection bonus for a playful action such as a dance.
    public mutating func registerPlay(points value: Int = 3) {
        points += max(0, value)
    }

    public var level: BondLevel { BondLevel.level(forPoints: points) }

    /// Progress toward the next bond level, in 0...1. Returns 1 at the final level.
    public var levelProgress: Double { BondLevel.progress(forPoints: points) }
}

public enum BondLevel: Int, CaseIterable, Comparable, Sendable {
    case newFriend = 0
    case pal
    case buddy
    case companion
    case soulmate

    public static func < (lhs: BondLevel, rhs: BondLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Affection points required to reach this level.
    public var threshold: Int {
        switch self {
        case .newFriend: 0
        case .pal: 20
        case .buddy: 60
        case .companion: 140
        case .soulmate: 300
        }
    }

    public var title: String {
        switch self {
        case .newFriend: "New Friend"
        case .pal: "Pal"
        case .buddy: "Buddy"
        case .companion: "Companion"
        case .soulmate: "Soulmate"
        }
    }

    /// Number of filled hearts to show for this level.
    public var hearts: Int { rawValue + 1 }

    public var next: BondLevel? { BondLevel(rawValue: rawValue + 1) }

    public static func level(forPoints points: Int) -> BondLevel {
        var result: BondLevel = .newFriend
        for level in BondLevel.allCases where points >= level.threshold {
            result = level
        }
        return result
    }

    public static func progress(forPoints points: Int) -> Double {
        let current = level(forPoints: points)
        guard let next = current.next else { return 1 }
        let span = Double(next.threshold - current.threshold)
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(points - current.threshold) / span))
    }
}
