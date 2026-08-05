import Foundation

public struct PetHeadAnchor: Equatable, Sendable {
    public let normalizedPoint: CGPoint

    public static func resolve(for petKind: PetKind) -> PetHeadAnchor {
        let point: CGPoint = switch petKind {
        case .cat:
            CGPoint(x: 0.44, y: 0.35)
        case .pauli:
            CGPoint(x: 0.50, y: 0.38)
        case .dog:
            CGPoint(x: 0.46, y: 0.39)
        }
        return PetHeadAnchor(normalizedPoint: point)
    }
}

public enum PetBubbleKind: Equatable, Sendable {
    case reminder
    case status
    case personality
}

public enum PetBubblePlacement: Equatable, Sendable {
    case leading
    case center
    case trailing
    case sideLeading
    case sideTrailing
}

public enum PetBubbleTailEdge: Equatable, Sendable {
    case bottom
    case leading
    case trailing
}

public struct PetBubbleGeometry: Equatable, Sendable {
    public let sceneWidth: Double
    public let artworkWidth: Double
    public let artworkHeight: Double
    public let artworkTop: Double
    public let bubbleWidth: Double
    public let sideBubbleWidth: Double
    public let sideBubbleHeight: Double
    public let horizontalPadding: Double
    public let sideHorizontalPadding: Double
    public let sideBubbleTopOffset: Double
    public let sideSceneHorizontalOffset: Double

    public static let standard = PetBubbleGeometry(
        sceneWidth: 260,
        artworkWidth: 190,
        artworkHeight: 198,
        artworkTop: 58,
        bubbleWidth: 194,
        sideBubbleWidth: 112,
        sideBubbleHeight: 76,
        horizontalPadding: 8,
        sideHorizontalPadding: 4,
        sideBubbleTopOffset: 70,
        sideSceneHorizontalOffset: 24
    )
}

public struct PetBubbleLayout: Equatable, Sendable {
    public let placement: PetBubblePlacement
    public let sceneVerticalOffset: Double
    public let sceneHorizontalOffset: Double
    public let bubbleWidth: Double
    public let bubbleHeight: Double?
    public let bubbleTopOffset: Double
    public let tailEdge: PetBubbleTailEdge
    public let tailHorizontalOffset: Double
    public let tailVerticalOffset: Double

    public static func resolve(
        kind: PetBubbleKind,
        placement: PetBubblePlacement = .center,
        geometry: PetBubbleGeometry = .standard
    ) -> PetBubbleLayout {
        makeLayout(
            kind: kind,
            placement: placement,
            target: CGPoint(
                x: geometry.sceneWidth / 2,
                y: geometry.artworkTop + geometry.artworkHeight * 0.38
            ),
            geometry: geometry
        )
    }

    public static func resolve(
        kind: PetBubbleKind,
        petKind: PetKind,
        placement: PetBubblePlacement = .center,
        geometry: PetBubbleGeometry = .standard
    ) -> PetBubbleLayout {
        let anchor = PetHeadAnchor.resolve(for: petKind)
        let artworkOriginX = (
            geometry.sceneWidth - geometry.artworkWidth
        ) / 2
        let targetX = artworkOriginX
            + anchor.normalizedPoint.x * geometry.artworkWidth
        return makeLayout(
            kind: kind,
            placement: placement,
            target: CGPoint(
                x: targetX,
                y: geometry.artworkTop
                    + anchor.normalizedPoint.y * geometry.artworkHeight
            ),
            geometry: geometry
        )
    }

    /// Aligns the bubble toward the side with more usable screen space. A
    /// centered dead zone prevents the bubble from jumping sides near the
    /// middle of a display.
    public static func resolve(
        kind: PetBubbleKind,
        windowMinX: Double,
        windowMaxX: Double,
        visibleMinX: Double,
        visibleMaxX: Double
    ) -> PetBubbleLayout {
        let values = [windowMinX, windowMaxX, visibleMinX, visibleMaxX]
        guard values.allSatisfy(\.isFinite),
              windowMaxX >= windowMinX,
              visibleMaxX > visibleMinX else {
            return resolve(kind: kind)
        }

        let spaceOnLeft = max(0, windowMinX - visibleMinX)
        let spaceOnRight = max(0, visibleMaxX - windowMaxX)
        let windowWidth = windowMaxX - windowMinX
        let centeredTolerance = max(16, windowWidth * 0.2)

        let placement: PetBubblePlacement
        if abs(spaceOnLeft - spaceOnRight) <= centeredTolerance {
            placement = .center
        } else if spaceOnLeft > spaceOnRight {
            placement = .leading
        } else {
            placement = .trailing
        }

        return resolve(kind: kind, placement: placement)
    }

    /// Uses a vertical side mount near the menu bar so short personality
    /// speech does not compress the pet underneath the bubble. Interactive
    /// reminder and status surfaces remain overhead when their full controls
    /// and information need the wider layout.
    public static func resolve(
        kind: PetBubbleKind,
        windowMinX: Double,
        windowMaxX: Double,
        windowMinY: Double,
        windowMaxY: Double,
        visibleMinX: Double,
        visibleMaxX: Double,
        visibleMinY: Double,
        visibleMaxY: Double
    ) -> PetBubbleLayout {
        let horizontal = resolve(
            kind: kind,
            windowMinX: windowMinX,
            windowMaxX: windowMaxX,
            visibleMinX: visibleMinX,
            visibleMaxX: visibleMaxX
        )
        let values = [windowMinY, windowMaxY, visibleMinY, visibleMaxY]
        guard values.allSatisfy(\.isFinite),
              windowMaxY >= windowMinY,
              visibleMaxY > visibleMinY else {
            return horizontal
        }

        let spaceAbove = max(0, visibleMaxY - windowMaxY)
        let windowHeight = windowMaxY - windowMinY
        let topTolerance = max(24, windowHeight * 0.18)
        guard spaceAbove <= topTolerance else { return horizontal }

        let placement: PetBubblePlacement = switch horizontal.placement {
        case .leading:
            .sideLeading
        case .center, .trailing:
            .sideTrailing
        case .sideLeading, .sideTrailing:
            horizontal.placement
        }
        return resolve(kind: kind, placement: placement)
    }

    private static func sceneVerticalOffset(for kind: PetBubbleKind) -> Double {
        switch kind {
        case .reminder:
            38
        case .status:
            26
        case .personality:
            18
        }
    }

    private static func makeLayout(
        kind: PetBubbleKind,
        placement requestedPlacement: PetBubblePlacement,
        target: CGPoint,
        geometry: PetBubbleGeometry
    ) -> PetBubbleLayout {
        let placement = normalizedPlacement(
            requestedPlacement,
            for: kind
        )
        let isSideMounted = placement == .sideLeading
            || placement == .sideTrailing
        let sceneHorizontalOffset: Double = switch placement {
        case .sideLeading:
            geometry.sideSceneHorizontalOffset
        case .sideTrailing:
            -geometry.sideSceneHorizontalOffset
        case .leading, .center, .trailing:
            0
        }
        let tailEdge: PetBubbleTailEdge = switch placement {
        case .sideLeading:
            .trailing
        case .sideTrailing:
            .leading
        case .leading, .center, .trailing:
            .bottom
        }

        return PetBubbleLayout(
            placement: placement,
            sceneVerticalOffset: isSideMounted
                ? 0
                : sceneVerticalOffset(for: kind),
            sceneHorizontalOffset: sceneHorizontalOffset,
            bubbleWidth: isSideMounted
                ? geometry.sideBubbleWidth
                : geometry.bubbleWidth,
            bubbleHeight: isSideMounted
                ? geometry.sideBubbleHeight
                : nil,
            bubbleTopOffset: isSideMounted
                ? geometry.sideBubbleTopOffset
                : 6,
            tailEdge: tailEdge,
            tailHorizontalOffset: isSideMounted
                ? 0
                : tailHorizontalOffset(
                    targetX: target.x,
                    placement: placement,
                    geometry: geometry
                ),
            tailVerticalOffset: isSideMounted
                ? min(
                    26,
                    max(
                        -26,
                        target.y
                            - geometry.sideBubbleTopOffset
                            - geometry.sideBubbleHeight / 2
                    )
                )
                : 0
        )
    }

    private static func normalizedPlacement(
        _ placement: PetBubblePlacement,
        for kind: PetBubbleKind
    ) -> PetBubblePlacement {
        guard kind != .personality else { return placement }
        return switch placement {
        case .sideLeading:
            .leading
        case .sideTrailing:
            .trailing
        case .leading, .center, .trailing:
            placement
        }
    }

    private static func tailHorizontalOffset(
        targetX: Double,
        placement: PetBubblePlacement,
        geometry: PetBubbleGeometry
    ) -> Double {
        let bubbleCenterX = switch placement {
        case .leading:
            geometry.horizontalPadding + geometry.bubbleWidth / 2
        case .center:
            geometry.sceneWidth / 2
        case .trailing:
            geometry.sceneWidth
                - geometry.horizontalPadding
                - geometry.bubbleWidth / 2
        case .sideLeading:
            geometry.sideHorizontalPadding + geometry.sideBubbleWidth / 2
        case .sideTrailing:
            geometry.sceneWidth
                - geometry.sideHorizontalPadding
                - geometry.sideBubbleWidth / 2
        }
        return min(64, max(-64, targetX - bubbleCenterX))
    }

}
