import Foundation
import CoreGraphics

public struct PetWindowAnchor: Codable, Equatable, Sendable {
    public static let `default` = PetWindowAnchor(
        horizontal: 0.96,
        vertical: 0.15
    )

    public let horizontal: Double
    public let vertical: Double

    public init(horizontal: Double, vertical: Double) {
        guard horizontal.isFinite, vertical.isFinite else {
            self = .default
            return
        }
        self.horizontal = min(1, max(0, horizontal))
        self.vertical = min(1, max(0, vertical))
    }

    public static func capture(
        windowFrame: CGRect,
        visibleFrame: CGRect
    ) -> PetWindowAnchor {
        guard windowFrame.isFiniteAndNonEmpty,
              visibleFrame.isFiniteAndNonEmpty else { return .default }

        let horizontalTravel = max(0, visibleFrame.width - windowFrame.width)
        let verticalTravel = max(0, visibleFrame.height - windowFrame.height)
        let safeX = min(
            visibleFrame.minX + horizontalTravel,
            max(visibleFrame.minX, windowFrame.minX)
        )
        let safeY = min(
            visibleFrame.minY + verticalTravel,
            max(visibleFrame.minY, windowFrame.minY)
        )

        return PetWindowAnchor(
            horizontal: horizontalTravel > 0
                ? (safeX - visibleFrame.minX) / horizontalTravel
                : 0.5,
            vertical: verticalTravel > 0
                ? (safeY - visibleFrame.minY) / verticalTravel
                : 0.5
        )
    }

    public func resolve(
        windowSize: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        guard windowSize.isFiniteAndNonEmpty,
              visibleFrame.isFiniteAndNonEmpty else { return .zero }

        let horizontalTravel = max(0, visibleFrame.width - windowSize.width)
        let verticalTravel = max(0, visibleFrame.height - windowSize.height)
        return CGPoint(
            x: visibleFrame.minX + horizontalTravel * horizontal,
            y: visibleFrame.minY + verticalTravel * vertical
        )
    }
}

private extension CGRect {
    var isFiniteAndNonEmpty: Bool {
        let values = [minX, minY, width, height]
        return values.allSatisfy(\.isFinite) && width > 0 && height > 0
    }
}

private extension CGSize {
    var isFiniteAndNonEmpty: Bool {
        width.isFinite && height.isFinite && width > 0 && height > 0
    }
}
