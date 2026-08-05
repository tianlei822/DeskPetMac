import CoreGraphics

public enum PetToyKind: String, CaseIterable, Equatable, Sendable {
    case laser
    case energyNode
    case ball

    public static func forPet(_ petKind: PetKind) -> PetToyKind {
        switch petKind {
        case .cat:
            .laser
        case .pauli:
            .energyNode
        case .dog:
            .ball
        }
    }

    public var displayName: String {
        switch self {
        case .laser:
            "Laser"
        case .energyNode:
            "Energy Node"
        case .ball:
            "Ball"
        }
    }
}

public struct PetToyTrajectory: Equatable, Sendable {
    public let start: CGPoint
    public let end: CGPoint
    public let arcHeight: Double

    public init(start: CGPoint, end: CGPoint, arcHeight: Double) {
        self.start = Self.clamp(start)
        self.end = Self.clamp(end)
        self.arcHeight = arcHeight.isFinite
            ? min(0.35, max(0, arcHeight))
            : 0
    }

    public func position(at progress: Double) -> CGPoint {
        let safeProgress = progress.isFinite
            ? min(1, max(0, progress))
            : 0
        let horizontal = start.x + (end.x - start.x) * safeProgress
        let linearVertical = start.y + (end.y - start.y) * safeProgress
        let arc = arcHeight * 4 * safeProgress * (1 - safeProgress)
        return Self.clamp(CGPoint(
            x: horizontal,
            y: linearVertical - arc
        ))
    }

    public static func clamp(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x.isFinite ? min(1, max(0, point.x)) : 0.5,
            y: point.y.isFinite ? min(1, max(0, point.y)) : 0.5
        )
    }
}
