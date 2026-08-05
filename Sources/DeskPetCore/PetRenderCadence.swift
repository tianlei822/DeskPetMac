public struct PetRenderCadence: Equatable, Sendable {
    public let maximumFramesPerSecond: Double
    public let isPaused: Bool

    public var minimumInterval: Double {
        1 / maximumFramesPerSecond
    }

    public static func resolve(
        reduceMotion: Bool,
        isVisible: Bool,
        isDirectInteraction: Bool,
        isActiveMotion: Bool
    ) -> PetRenderCadence {
        let maximumFramesPerSecond: Double
        if reduceMotion {
            maximumFramesPerSecond = 8
        } else if isDirectInteraction {
            maximumFramesPerSecond = 60
        } else if isActiveMotion {
            maximumFramesPerSecond = 30
        } else {
            maximumFramesPerSecond = 12
        }

        return PetRenderCadence(
            maximumFramesPerSecond: maximumFramesPerSecond,
            isPaused: !isVisible
        )
    }
}
