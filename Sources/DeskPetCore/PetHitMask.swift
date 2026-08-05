import Foundation

public enum PetHitMask {
    public static func contains(
        normalizedPoint point: CGPoint,
        petKind: PetKind
    ) -> Bool {
        guard point.x.isFinite,
              point.y.isFinite,
              (0...1).contains(point.x),
              (0...1).contains(point.y) else { return false }

        return zones(for: petKind).contains { $0.contains(point) }
    }

    private static func zones(for petKind: PetKind) -> [HitEllipse] {
        switch petKind {
        case .cat:
            [
                HitEllipse(centerX: 0.47, centerY: 0.38, radiusX: 0.22, radiusY: 0.19),
                HitEllipse(centerX: 0.50, centerY: 0.65, radiusX: 0.27, radiusY: 0.30),
                HitEllipse(centerX: 0.73, centerY: 0.48, radiusX: 0.15, radiusY: 0.27),
            ]
        case .pauli:
            [
                HitEllipse(centerX: 0.50, centerY: 0.40, radiusX: 0.24, radiusY: 0.20),
                HitEllipse(centerX: 0.50, centerY: 0.65, radiusX: 0.25, radiusY: 0.31),
            ]
        case .dog:
            [
                HitEllipse(centerX: 0.48, centerY: 0.39, radiusX: 0.24, radiusY: 0.20),
                HitEllipse(centerX: 0.50, centerY: 0.65, radiusX: 0.29, radiusY: 0.30),
                HitEllipse(centerX: 0.74, centerY: 0.48, radiusX: 0.14, radiusY: 0.24),
            ]
        }
    }
}

private struct HitEllipse {
    let centerX: Double
    let centerY: Double
    let radiusX: Double
    let radiusY: Double

    func contains(_ point: CGPoint) -> Bool {
        let horizontal = (point.x - centerX) / radiusX
        let vertical = (point.y - centerY) / radiusY
        return horizontal * horizontal + vertical * vertical <= 1
    }
}
