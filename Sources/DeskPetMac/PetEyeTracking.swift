import DeskPetCore
import Foundation
import SwiftUI

enum PetEyeArtworkPose: CaseIterable, Equatable {
    case base
    case hover
}

enum PetEyeArtworkPolicy {
    static func pose(
        kind: PetKind,
        resourceName: String
    ) -> PetEyeArtworkPose? {
        let manifest = PetArtworkManifest(petKind: kind)
        if resourceName == manifest.base { return .base }
        if resourceName == manifest.hover { return .hover }
        return nil
    }
}

enum PetEyeGazeMotion {
    private static let deadZone = 0.06

    static func direction(for pointer: CGSize) -> CGSize {
        let x = Double(pointer.width)
        let y = Double(pointer.height)
        guard x.isFinite, y.isFinite else { return .zero }

        let distance = hypot(x, y)
        guard distance > deadZone else { return .zero }

        let progress = min(1, (distance - deadZone) / (1 - deadZone))
        let eased = progress * progress * (3 - 2 * progress)
        return CGSize(
            width: x / distance * eased,
            height: y / distance * eased
        )
    }
}

struct PetEyeLayout {
    let leftCenter: UnitPoint
    let rightCenter: UnitPoint
    let pupilSize: CGSize
    let maximumTravel: CGSize
    let pupilColor: Color
    let highlightColor: Color

    static func layout(
        for kind: PetKind,
        pose: PetEyeArtworkPose
    ) -> PetEyeLayout {
        switch (kind, pose) {
        case (.cat, .base):
            return PetEyeLayout(
                leftCenter: UnitPoint(x: 0.355, y: 0.275),
                rightCenter: UnitPoint(x: 0.438, y: 0.267),
                pupilSize: CGSize(width: 2.0, height: 5.0),
                maximumTravel: CGSize(width: 1.45, height: 1.0),
                pupilColor: .black.opacity(0.76),
                highlightColor: .white.opacity(0.72)
            )
        case (.cat, .hover):
            return PetEyeLayout(
                leftCenter: UnitPoint(x: 0.369, y: 0.240),
                rightCenter: UnitPoint(x: 0.446, y: 0.229),
                pupilSize: CGSize(width: 2.0, height: 5.0),
                maximumTravel: CGSize(width: 1.45, height: 1.0),
                pupilColor: .black.opacity(0.76),
                highlightColor: .white.opacity(0.72)
            )
        case (.dog, .base):
            return PetEyeLayout(
                leftCenter: UnitPoint(x: 0.384, y: 0.348),
                rightCenter: UnitPoint(x: 0.487, y: 0.352),
                pupilSize: CGSize(width: 2.8, height: 3.1),
                maximumTravel: CGSize(width: 1.2, height: 0.9),
                pupilColor: Color(red: 0.08, green: 0.04, blue: 0.02)
                    .opacity(0.68),
                highlightColor: .white.opacity(0.68)
            )
        case (.dog, .hover):
            return PetEyeLayout(
                leftCenter: UnitPoint(x: 0.339, y: 0.216),
                rightCenter: UnitPoint(x: 0.416, y: 0.237),
                pupilSize: CGSize(width: 2.8, height: 3.1),
                maximumTravel: CGSize(width: 1.2, height: 0.9),
                pupilColor: Color(red: 0.08, green: 0.04, blue: 0.02)
                    .opacity(0.68),
                highlightColor: .white.opacity(0.68)
            )
        case (.pauli, .base):
            return PetEyeLayout(
                leftCenter: UnitPoint(x: 0.423, y: 0.326),
                rightCenter: UnitPoint(x: 0.532, y: 0.331),
                pupilSize: CGSize(width: 4.0, height: 5.0),
                maximumTravel: CGSize(width: 2.2, height: 1.5),
                pupilColor: Color(red: 0.01, green: 0.22, blue: 0.24)
                    .opacity(0.68),
                highlightColor: Color.cyan.opacity(0.58)
            )
        case (.pauli, .hover):
            return PetEyeLayout(
                leftCenter: UnitPoint(x: 0.402, y: 0.285),
                rightCenter: UnitPoint(x: 0.505, y: 0.310),
                pupilSize: CGSize(width: 4.0, height: 5.0),
                maximumTravel: CGSize(width: 2.2, height: 1.5),
                pupilColor: Color(red: 0.01, green: 0.22, blue: 0.24)
                    .opacity(0.68),
                highlightColor: Color.cyan.opacity(0.58)
            )
        }
    }
}

struct PetEyeGazeOverlay: View {
    private static let artworkSize = CGSize(width: 190, height: 198)

    let kind: PetKind
    let artworkPose: PetEyeArtworkPose
    let direction: CGSize

    var body: some View {
        let layout = PetEyeLayout.layout(for: kind, pose: artworkPose)
        let offset = CGSize(
            width: direction.width * layout.maximumTravel.width,
            height: direction.height * layout.maximumTravel.height
        )

        ZStack(alignment: .topLeading) {
            pupil(at: layout.leftCenter, layout: layout, offset: offset)
            pupil(at: layout.rightCenter, layout: layout, offset: offset)
        }
        .frame(
            width: Self.artworkSize.width,
            height: Self.artworkSize.height
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func pupil(
        at center: UnitPoint,
        layout: PetEyeLayout,
        offset: CGSize
    ) -> some View {
        ZStack(alignment: .topLeading) {
            Ellipse().fill(layout.pupilColor)
            Circle()
                .fill(layout.highlightColor)
                .frame(width: 0.8, height: 0.8)
                .offset(x: 0.35, y: 0.35)
        }
        .frame(width: layout.pupilSize.width, height: layout.pupilSize.height)
        .position(
            x: Self.artworkSize.width * center.x + offset.width,
            y: Self.artworkSize.height * center.y + offset.height
        )
    }
}
