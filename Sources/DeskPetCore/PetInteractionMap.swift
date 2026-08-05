import Foundation

public enum PetInteractionZone: Equatable, Sendable {
    case noseOrSensor
    case head
    case torso
    case none
}

public enum PetInteractionMap {
    public static func resolve(
        normalizedPoint point: CGPoint,
        petKind: PetKind
    ) -> PetInteractionZone {
        guard point.x.isFinite,
              point.y.isFinite,
              (0...1).contains(point.x),
              (0...1).contains(point.y) else { return .none }

        let anchors = anchors(for: petKind)
        if anchors.noseOrSensor.contains(point) {
            return .noseOrSensor
        }
        if anchors.head.contains(point) {
            return .head
        }
        if anchors.torso.contains(point) {
            return .torso
        }
        return .none
    }

    private static func anchors(for petKind: PetKind) -> InteractionAnchors {
        switch petKind {
        case .cat:
            InteractionAnchors(
                noseOrSensor: InteractionEllipse(
                    centerX: 0.44,
                    centerY: 0.35,
                    radiusX: 0.07,
                    radiusY: 0.055
                ),
                head: InteractionEllipse(
                    centerX: 0.46,
                    centerY: 0.39,
                    radiusX: 0.23,
                    radiusY: 0.20
                ),
                torso: InteractionEllipse(
                    centerX: 0.50,
                    centerY: 0.67,
                    radiusX: 0.29,
                    radiusY: 0.29
                )
            )
        case .pauli:
            InteractionAnchors(
                noseOrSensor: InteractionEllipse(
                    centerX: 0.50,
                    centerY: 0.38,
                    radiusX: 0.065,
                    radiusY: 0.06
                ),
                head: InteractionEllipse(
                    centerX: 0.50,
                    centerY: 0.40,
                    radiusX: 0.24,
                    radiusY: 0.20
                ),
                torso: InteractionEllipse(
                    centerX: 0.50,
                    centerY: 0.66,
                    radiusX: 0.26,
                    radiusY: 0.30
                )
            )
        case .dog:
            InteractionAnchors(
                noseOrSensor: InteractionEllipse(
                    centerX: 0.46,
                    centerY: 0.39,
                    radiusX: 0.075,
                    radiusY: 0.06
                ),
                head: InteractionEllipse(
                    centerX: 0.48,
                    centerY: 0.40,
                    radiusX: 0.25,
                    radiusY: 0.21
                ),
                torso: InteractionEllipse(
                    centerX: 0.50,
                    centerY: 0.67,
                    radiusX: 0.30,
                    radiusY: 0.29
                )
            )
        }
    }
}

private struct InteractionAnchors {
    let noseOrSensor: InteractionEllipse
    let head: InteractionEllipse
    let torso: InteractionEllipse
}

private struct InteractionEllipse {
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
