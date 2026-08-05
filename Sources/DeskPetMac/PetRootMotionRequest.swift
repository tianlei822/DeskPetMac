import DeskPetCore
import Foundation

struct PetRootMotionRequest: Equatable, Sendable {
    let id: UUID
    let desiredDistance: Double
    let preferredDirection: PetRootMotionDirection

    init(
        id: UUID = UUID(),
        desiredDistance: Double,
        preferredDirection: PetRootMotionDirection
    ) {
        self.id = id
        self.desiredDistance = desiredDistance
        self.preferredDirection = preferredDirection
    }
}
