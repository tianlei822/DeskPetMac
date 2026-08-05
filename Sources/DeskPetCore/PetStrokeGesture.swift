import Foundation

public enum PetScratchRegion: String, Equatable, Sendable {
    case earOrTemple
    case chin
}

public enum PetSwipeDirection: String, Equatable, Sendable {
    case left
    case right
    case up
    case down
}

public enum PetStrokeGesture: Equatable, Sendable {
    case scratch(PetScratchRegion)
    case swipe(direction: PetSwipeDirection, intensity: Double)
    case none
}

public struct PetStrokePath: Equatable, Sendable {
    public let start: CGPoint
    public let end: CGPoint
    public let centroid: CGPoint
    public let duration: TimeInterval
    public let travelDistance: Double
    public let reversalCount: Int

    public init(
        start: CGPoint,
        end: CGPoint,
        centroid: CGPoint,
        duration: TimeInterval,
        travelDistance: Double,
        reversalCount: Int
    ) {
        self.start = start
        self.end = end
        self.centroid = centroid
        self.duration = duration
        self.travelDistance = travelDistance
        self.reversalCount = max(0, reversalCount)
    }
}

public struct PetStrokePathTracker: Equatable, Sendable {
    private let start: CGPoint
    private let startedAt: TimeInterval
    private var end: CGPoint
    private var lastTimestamp: TimeInterval
    private var accumulatedX: Double
    private var accumulatedY: Double
    private var sampleCount: Int
    private var travelDistance: Double
    private var lastDirection: CGVector?
    private var reversalCount: Int

    public init(start: CGPoint, timestamp: TimeInterval) {
        self.start = start
        self.startedAt = timestamp
        self.end = start
        self.lastTimestamp = timestamp
        self.accumulatedX = start.x
        self.accumulatedY = start.y
        self.sampleCount = 1
        self.travelDistance = 0
        self.lastDirection = nil
        self.reversalCount = 0
    }

    public mutating func append(_ point: CGPoint, timestamp: TimeInterval) {
        guard point.x.isFinite,
              point.y.isFinite,
              timestamp.isFinite,
              timestamp >= lastTimestamp else { return }

        let horizontal = point.x - end.x
        let vertical = point.y - end.y
        let segmentDistance = hypot(horizontal, vertical)
        guard segmentDistance.isFinite else { return }

        travelDistance += segmentDistance
        if segmentDistance >= 0.006 {
            let direction = CGVector(
                dx: horizontal / segmentDistance,
                dy: vertical / segmentDistance
            )
            if let lastDirection {
                let dot = lastDirection.dx * direction.dx
                    + lastDirection.dy * direction.dy
                if dot < -0.35 {
                    reversalCount += 1
                }
            }
            lastDirection = direction
        }

        end = point
        lastTimestamp = timestamp
        accumulatedX += point.x
        accumulatedY += point.y
        sampleCount += 1
    }

    public var path: PetStrokePath {
        PetStrokePath(
            start: start,
            end: end,
            centroid: CGPoint(
                x: accumulatedX / Double(sampleCount),
                y: accumulatedY / Double(sampleCount)
            ),
            duration: lastTimestamp - startedAt,
            travelDistance: travelDistance,
            reversalCount: reversalCount
        )
    }
}

public enum PetStrokeGestureResolver {
    public static func isScratchCandidate(
        at point: CGPoint,
        petKind: PetKind
    ) -> Bool {
        guard isNormalized(point) else { return false }
        return scratchRegion(at: point, petKind: petKind) != nil
    }

    public static func resolve(
        start: CGPoint,
        end: CGPoint,
        duration: TimeInterval,
        petKind: PetKind
    ) -> PetStrokeGesture {
        guard isNormalized(start),
              isNormalized(end),
              duration.isFinite,
              duration > 0 else { return .none }

        let horizontal = end.x - start.x
        let vertical = end.y - start.y
        let distance = hypot(horizontal, vertical)
        let midpoint = CGPoint(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2
        )
        return resolve(
            path: PetStrokePath(
                start: start,
                end: end,
                centroid: midpoint,
                duration: duration,
                travelDistance: distance,
                reversalCount: 0
            ),
            petKind: petKind
        )
    }

    public static func resolve(
        path: PetStrokePath,
        petKind: PetKind
    ) -> PetStrokeGesture {
        guard isNormalized(path.start),
              isNormalized(path.end),
              isNormalized(path.centroid),
              path.duration.isFinite,
              path.duration > 0,
              path.travelDistance.isFinite,
              path.travelDistance >= 0 else { return .none }

        let horizontal = path.end.x - path.start.x
        let vertical = path.end.y - path.start.y
        let distance = hypot(horizontal, vertical)
        let speed = distance / path.duration
        let averageSpeed = path.travelDistance / path.duration
        let efficiency = path.travelDistance > 0
            ? distance / path.travelDistance
            : 0

        if distance >= 0.16, speed >= 0.85, efficiency >= 0.72 {
            let direction: PetSwipeDirection
            if abs(horizontal) >= abs(vertical) {
                direction = horizontal >= 0 ? .right : .left
            } else {
                direction = vertical >= 0 ? .down : .up
            }
            let intensity = min(1, max(0.25, (speed - 0.7) / 2.6))
            return .swipe(direction: direction, intensity: intensity)
        }

        guard (0.18...1.6).contains(path.duration) else { return .none }
        let isSimpleScratch = (0.025...0.22).contains(distance)
            && speed <= 0.65
            && path.travelDistance <= 0.26
        let isReturningScratch = path.reversalCount >= 1
            && (0.05...0.65).contains(path.travelDistance)
            && averageSpeed <= 1.35
            && efficiency <= 0.72
        guard isSimpleScratch || isReturningScratch else { return .none }

        let startRegion = scratchRegion(at: path.start, petKind: petKind)
        let centroidRegion = scratchRegion(at: path.centroid, petKind: petKind)
        if isReturningScratch {
            guard let startRegion, startRegion == centroidRegion else {
                return .none
            }
            return .scratch(startRegion)
        }
        return (startRegion ?? centroidRegion).map(PetStrokeGesture.scratch)
            ?? .none
    }

    private static func scratchRegion(
        at point: CGPoint,
        petKind: PetKind
    ) -> PetScratchRegion? {
        let anchors = scratchAnchors(for: petKind)
        if anchors.ears.contains(where: { $0.contains(point) }) {
            return .earOrTemple
        }
        if anchors.chin.contains(point) {
            return .chin
        }
        return nil
    }

    private static func scratchAnchors(for petKind: PetKind) -> ScratchAnchors {
        switch petKind {
        case .cat:
            ScratchAnchors(
                ears: [
                    ScratchEllipse(center: CGPoint(x: 0.32, y: 0.25), radiusX: 0.13, radiusY: 0.12),
                    ScratchEllipse(center: CGPoint(x: 0.61, y: 0.25), radiusX: 0.13, radiusY: 0.12),
                ],
                chin: ScratchEllipse(center: CGPoint(x: 0.47, y: 0.48), radiusX: 0.17, radiusY: 0.11)
            )
        case .pauli:
            ScratchAnchors(
                ears: [
                    ScratchEllipse(center: CGPoint(x: 0.30, y: 0.33), radiusX: 0.13, radiusY: 0.13),
                    ScratchEllipse(center: CGPoint(x: 0.70, y: 0.33), radiusX: 0.13, radiusY: 0.13),
                ],
                chin: ScratchEllipse(center: CGPoint(x: 0.50, y: 0.50), radiusX: 0.17, radiusY: 0.10)
            )
        case .dog:
            ScratchAnchors(
                ears: [
                    ScratchEllipse(center: CGPoint(x: 0.30, y: 0.30), radiusX: 0.15, radiusY: 0.14),
                    ScratchEllipse(center: CGPoint(x: 0.66, y: 0.30), radiusX: 0.15, radiusY: 0.14),
                ],
                chin: ScratchEllipse(center: CGPoint(x: 0.48, y: 0.49), radiusX: 0.18, radiusY: 0.11)
            )
        }
    }

    private static func isNormalized(_ point: CGPoint) -> Bool {
        point.x.isFinite
            && point.y.isFinite
            && (0...1).contains(point.x)
            && (0...1).contains(point.y)
    }
}

private struct ScratchAnchors {
    let ears: [ScratchEllipse]
    let chin: ScratchEllipse
}

private struct ScratchEllipse {
    let center: CGPoint
    let radiusX: Double
    let radiusY: Double

    func contains(_ point: CGPoint) -> Bool {
        let horizontal = (point.x - center.x) / radiusX
        let vertical = (point.y - center.y) / radiusY
        return horizontal * horizontal + vertical * vertical <= 1
    }
}
