import DeskPetCore
import Foundation

/// Presentation-space adaptations of cybopal-client's sitting/reclined/
/// standing/portrait concepts. These are not physical robot commands or limits.
struct CyboPalArmPosture: Equatable {
    var reach: Double
    var height: Double
    var tilt: Double = 0
    var roll: Double = 0
    var yaw: Double = -0.25

    static let sitting = Self(reach: 20, height: 100, tilt: 5 * .pi / 180)
    static let reclined = Self(reach: 12, height: 108, tilt: -12 * .pi / 180)
    static let standing = Self(reach: 12, height: 115)
    static let portrait = Self(reach: 18, height: 102, roll: .pi / 2)
    static let resting = Self(reach: 4, height: 72, tilt: 0.30, yaw: -0.10)

    func blended(to other: Self, amount: Double) -> Self {
        let t = min(1, max(0, amount))
        return Self(reach: reach + (other.reach - reach) * t,
                    height: height + (other.height - height) * t,
                    tilt: tilt + (other.tilt - tilt) * t,
                    roll: roll + (other.roll - roll) * t,
                    yaw: yaw + (other.yaw - yaw) * t)
    }
}

enum CyboPalArmAction: CaseIterable {
    case idle, observe, reach, lift, portrait, celebrate, rest

    static func resolve(activity: PetActivityKind, personality: PersonalityPose?,
                        event: PetMotionEvent) -> Self {
        switch activity {
        case .sleeping: return .rest
        case .feeding, .nuzzling: return .reach
        case .dancing: return .celebrate
        case .reminder: return .lift
        default: break
        }
        switch personality {
        case .stretch, .perk: return .lift
        case .peek: return .observe
        case .proud: return .portrait
        case nil: break
        }
        switch event {
        case .walk, .lookAround: return .observe
        case .idleAction1: return .reach
        case .idleAction2: return .portrait
        case .stretch, .perkUp: return .lift
        case .idle: return .idle
        }
    }

    var duration: Double {
        switch self {
        case .observe: 3.5
        case .reach: 3.2
        case .lift: 3.5
        case .portrait: 3.5
        case .celebrate: PetAnimationDynamics.danceDuration
        case .idle, .rest: 1
        }
    }
}

enum CyboPalArmMotion {
    /// Anticipation → travel → hold → settle. Quintic interpolation reaches
    /// every waypoint with zero velocity and acceleration.
    static func posture(action: CyboPalArmAction, progress: Double) -> CyboPalArmPosture {
        if action == .rest { return .resting }
        let p = progress.isFinite ? min(1, max(0, progress)) : 0
        guard p > 0, p < 1, action != .idle else { return .sitting }
        let anticipation = CyboPalArmPosture(reach: 18, height: 97, tilt: 0.10)
        let waypoints: [(Double, CyboPalArmPosture)]
        switch action {
        case .observe:
            waypoints = [(0, .sitting), (0.12, anticipation),
                (0.34, .init(reach: 12, height: 105, tilt: -0.08, yaw: -0.60)),
                (0.66, .init(reach: 27, height: 101, tilt: 0.12, yaw: 0.28)),
                (1, .sitting)]
        case .reach:
            waypoints = [(0, .sitting), (0.14, .reclined),
                (0.46, .init(reach: 36, height: 90, tilt: 0.24)),
                (0.65, .init(reach: 36, height: 90, tilt: 0.24)), (1, .sitting)]
        case .lift:
            waypoints = [(0, .sitting), (0.14, anticipation),
                (0.46, .standing), (0.68, .standing), (1, .sitting)]
        case .portrait:
            waypoints = [(0, .sitting), (0.16, .reclined),
                (0.50, .portrait), (0.68, .portrait), (1, .sitting)]
        case .celebrate:
            waypoints = [(0, .sitting), (0.12, anticipation),
                (0.33, .init(reach: 12, height: 110, tilt: -0.12, roll: -0.20, yaw: -0.45)),
                (0.63, .init(reach: 30, height: 99, tilt: 0.18, roll: 0.22, yaw: 0.12)),
                (1, .sitting)]
        case .idle, .rest: return .sitting
        }
        for index in 1..<waypoints.count where p <= waypoints[index].0 {
            let before = waypoints[index - 1]
            let after = waypoints[index]
            let t = (p - before.0) / (after.0 - before.0)
            let eased = t * t * t * (10 + t * (-15 + 6 * t))
            return before.1.blended(to: after.1, amount: eased)
        }
        return .sitting
    }
}

@MainActor
final class CyboPalArmTimeline {
    private var action: CyboPalArmAction?
    private var startedAt = 0.0
    private var previousTime = 0.0

    func progress(for next: CyboPalArmAction, at time: Double) -> Double {
        guard time.isFinite else { return 0 }
        if action != next || time < previousTime {
            action = next
            startedAt = time
        } else if time - previousTime > 0.25 {
            // Do not skip the gesture after the pet window resumes rendering.
            startedAt += time - previousTime
        }
        previousTime = time
        return min(1, max(0, (time - startedAt) / next.duration))
    }
}

struct CyboPalArmSample {
    let pose: CyboPalRobotPose
    let eyeDirection: CGSize
    let eyeClosure: Double
}

/// Smooth the end-effector intent before solving joints. Interpolating already
/// solved angles can swing screen corners outside otherwise valid endpoints.
@MainActor
final class CyboPalArmPresentation {
    private let presentation = PetContinuousPresentation()

    func sample(posture: CyboPalArmPosture, attention: CGSize,
                gesture: PetAnimationPose, eyeClosure: Double,
                at time: Double, immediate: Bool) -> CyboPalArmSample {
        let values = presentation.sample([
            posture.reach, posture.height, posture.tilt, posture.roll, posture.yaw,
            gesture.x, gesture.y, gesture.tiltDegrees,
            attention.width, attention.height, eyeClosure,
        ], at: time, immediate: immediate)
        let eyes = CGSize(width: values[8], height: values[9])
        let pose = CyboPalRobotPose.target(
            posture: .init(reach: values[0], height: values[1], tilt: values[2],
                           roll: values[3], yaw: values[4]),
            attention: eyes,
            gesture: .init(x: values[5], y: values[6], scale: 1, tiltDegrees: values[7]))
        return CyboPalArmSample(pose: pose, eyeDirection: eyes, eyeClosure: values[10])
    }
}
