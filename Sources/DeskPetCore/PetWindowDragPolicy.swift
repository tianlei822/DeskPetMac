import Foundation

public enum PetWindowDragPolicy {
    public static let minimumDuration: TimeInterval = 0.28
    public static let minimumDistance: Double = 28

    public static func shouldActivate(
        elapsed: TimeInterval,
        translation: CGSize
    ) -> Bool {
        guard elapsed.isFinite,
              translation.width.isFinite,
              translation.height.isFinite,
              elapsed >= minimumDuration else { return false }

        return hypot(translation.width, translation.height) >= minimumDistance
    }
}
