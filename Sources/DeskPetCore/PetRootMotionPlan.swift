import Foundation

public enum PetRootMotionDirection: Int, Equatable, Sendable {
    case left = -1
    case right = 1
}

public enum PetRootMotionPhase: Equatable, Sendable {
    case notice
    case anticipate
    case turning
    case walking
    case slowing
    case settling
    case completed
}

public extension PetRootMotionPhase {
    var transitionPose: PetTransitionPose? {
        switch self {
        case .anticipate:
            .anticipate
        case .turning:
            .turn
        case .settling:
            .settle
        case .notice, .walking, .slowing, .completed:
            nil
        }
    }
}

public struct PetRootMotionFrame: Equatable, Sendable {
    public let windowX: Double
    public let progress: Double
    public let phase: PetRootMotionPhase
    public let phaseProgress: Double
    public let travelProgress: Double
    public let stridePhase: Double
    public let stepIndex: Int
    public let stepCount: Int
    public let direction: PetRootMotionDirection
}

public struct PetRootMotionPlan: Equatable, Sendable {
    public let startX: Double
    public let targetX: Double
    public let distance: Double
    public let duration: Double
    public let direction: PetRootMotionDirection
    public let stepCount: Int
    public let preparationDuration: Double
    public let movementDuration: Double
    public let settlingDuration: Double

    public static func resolve(
        startX: Double,
        visibleMinX: Double,
        visibleMaxX: Double,
        windowWidth: Double,
        desiredDistance: Double,
        preferredDirection: PetRootMotionDirection
    ) -> PetRootMotionPlan {
        let values = [
            startX,
            visibleMinX,
            visibleMaxX,
            windowWidth,
            desiredDistance,
        ]
        guard values.allSatisfy(\.isFinite),
              visibleMaxX > visibleMinX,
              windowWidth > 0 else {
            return stationary(at: 0, direction: preferredDirection)
        }

        let safeMinX = visibleMinX
        let safeMaxX = max(safeMinX, visibleMaxX - windowWidth)
        let safeStartX = min(safeMaxX, max(safeMinX, startX))
        let requestedDistance = min(160, max(60, desiredDistance))
        let roomOnLeft = max(0, safeStartX - safeMinX)
        let roomOnRight = max(0, safeMaxX - safeStartX)
        let preferredRoom = preferredDirection == .left
            ? roomOnLeft
            : roomOnRight
        let alternateRoom = preferredDirection == .left
            ? roomOnRight
            : roomOnLeft

        let direction: PetRootMotionDirection
        if preferredRoom >= requestedDistance || preferredRoom >= alternateRoom {
            direction = preferredDirection
        } else {
            direction = preferredDirection == .left ? .right : .left
        }

        let availableDistance = direction == .left ? roomOnLeft : roomOnRight
        let distance = min(requestedDistance, availableDistance)
        guard distance > 0 else {
            return stationary(at: safeStartX, direction: direction)
        }

        let targetX = safeStartX + Double(direction.rawValue) * distance
        let stepCount = min(6, max(2, Int(ceil(distance / 30))))
        let preparationDuration = 0.62
        let movementDuration = Double(stepCount) / 1.1
        let settlingDuration = 0.62
        return PetRootMotionPlan(
            startX: safeStartX,
            targetX: targetX,
            distance: distance,
            duration: preparationDuration + movementDuration + settlingDuration,
            direction: direction,
            stepCount: stepCount,
            preparationDuration: preparationDuration,
            movementDuration: movementDuration,
            settlingDuration: settlingDuration
        )
    }

    public func frame(at elapsed: Double) -> PetRootMotionFrame {
        guard duration > 0, elapsed.isFinite else {
            return PetRootMotionFrame(
                windowX: targetX,
                progress: 1,
                phase: .completed,
                phaseProgress: 1,
                travelProgress: distance > 0 ? 1 : 0,
                stridePhase: 1,
                stepIndex: max(0, stepCount - 1),
                stepCount: stepCount,
                direction: direction
            )
        }

        let safeElapsed = max(0, elapsed)
        let progress = min(1, safeElapsed / duration)
        if safeElapsed >= duration {
            return PetRootMotionFrame(
                windowX: targetX,
                progress: 1,
                phase: .completed,
                phaseProgress: 1,
                travelProgress: 1,
                stridePhase: 1,
                stepIndex: max(0, stepCount - 1),
                stepCount: stepCount,
                direction: direction
            )
        }

        let noticeDuration = preparationDuration * 0.34
        let anticipateDuration = preparationDuration * 0.36
        if safeElapsed < noticeDuration {
            return PetRootMotionFrame(
                windowX: startX,
                progress: progress,
                phase: .notice,
                phaseProgress: safeElapsed / noticeDuration,
                travelProgress: 0,
                stridePhase: 0,
                stepIndex: 0,
                stepCount: stepCount,
                direction: direction
            )
        }
        let anticipateEnd = noticeDuration + anticipateDuration
        if safeElapsed < anticipateEnd {
            return PetRootMotionFrame(
                windowX: startX,
                progress: progress,
                phase: .anticipate,
                phaseProgress: (safeElapsed - noticeDuration)
                    / anticipateDuration,
                travelProgress: 0,
                stridePhase: 0,
                stepIndex: 0,
                stepCount: stepCount,
                direction: direction
            )
        }
        if safeElapsed < preparationDuration {
            return PetRootMotionFrame(
                windowX: startX,
                progress: progress,
                phase: .turning,
                phaseProgress: (safeElapsed - anticipateEnd)
                    / (preparationDuration - anticipateEnd),
                travelProgress: 0,
                stridePhase: 0,
                stepIndex: 0,
                stepCount: stepCount,
                direction: direction
            )
        }

        let movementElapsed = safeElapsed - preparationDuration
        if movementElapsed < movementDuration {
            let movementProgress = movementElapsed / movementDuration
            let stepPosition = min(
                Double(stepCount) - Double.ulpOfOne,
                movementProgress * Double(stepCount)
            )
            let stepIndex = min(
                stepCount - 1,
                max(0, Int(stepPosition.rounded(.down)))
            )
            let stridePhase = stepPosition - Double(stepIndex)
            let localTravel: Double
            if stridePhase <= 0.13 {
                localTravel = 0
            } else if stridePhase >= 0.84 {
                localTravel = 1
            } else {
                let swingProgress = (stridePhase - 0.13) / 0.71
                localTravel = smoothStep(swingProgress)
            }
            let travelProgress = min(
                1,
                (Double(stepIndex) + localTravel) / Double(stepCount)
            )
            let phase: PetRootMotionPhase = movementProgress < 0.78
                ? .walking
                : .slowing
            let phaseProgress = phase == .walking
                ? movementProgress / 0.78
                : (movementProgress - 0.78) / 0.22
            return PetRootMotionFrame(
                windowX: startX + (targetX - startX) * travelProgress,
                progress: progress,
                phase: phase,
                phaseProgress: min(1, max(0, phaseProgress)),
                travelProgress: travelProgress,
                stridePhase: stridePhase,
                stepIndex: stepIndex,
                stepCount: stepCount,
                direction: direction
            )
        }

        let settleElapsed = safeElapsed - preparationDuration - movementDuration
        return PetRootMotionFrame(
            windowX: targetX,
            progress: progress,
            phase: .settling,
            phaseProgress: min(1, max(0, settleElapsed / settlingDuration)),
            travelProgress: 1,
            stridePhase: 1,
            stepIndex: max(0, stepCount - 1),
            stepCount: stepCount,
            direction: direction
        )
    }

    private func smoothStep(_ value: Double) -> Double {
        let clamped = min(1, max(0, value))
        return clamped * clamped * (3 - 2 * clamped)
    }

    private static func stationary(
        at startX: Double,
        direction: PetRootMotionDirection
    ) -> PetRootMotionPlan {
        PetRootMotionPlan(
            startX: startX,
            targetX: startX,
            distance: 0,
            duration: 0,
            direction: direction,
            stepCount: 0,
            preparationDuration: 0,
            movementDuration: 0,
            settlingDuration: 0
        )
    }
}
