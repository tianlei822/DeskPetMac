import Foundation

public enum PetWakeRitualPhase: String, CaseIterable, Equatable, Sendable {
  case stretching
  case orienting

  public var pose: PersonalityPose {
    switch self {
    case .stretching:
      .stretch
    case .orienting:
      .perk
    }
  }
}

public struct PetWakeRitualTiming: Equatable, Sendable {
  public static let standard = PetWakeRitualTiming(
    stretchDuration: 0.82,
    orientDuration: 0.62,
    reducedMotionDuration: 0.32
  )

  public let stretchDuration: TimeInterval
  public let orientDuration: TimeInterval
  public let reducedMotionDuration: TimeInterval

  public init(
    stretchDuration: TimeInterval,
    orientDuration: TimeInterval,
    reducedMotionDuration: TimeInterval
  ) {
    self.stretchDuration = Self.safeDuration(
      stretchDuration,
      fallback: 0.82
    )
    self.orientDuration = Self.safeDuration(
      orientDuration,
      fallback: 0.62
    )
    self.reducedMotionDuration = Self.safeDuration(
      reducedMotionDuration,
      fallback: 0.32
    )
  }

  private static func safeDuration(
    _ duration: TimeInterval,
    fallback: TimeInterval
  ) -> TimeInterval {
    guard duration.isFinite else { return fallback }
    return min(3, max(0.05, duration))
  }
}

public struct PetWakeRitualStep: Equatable, Sendable {
  public let phase: PetWakeRitualPhase
  public let duration: TimeInterval

  public var pose: PersonalityPose { phase.pose }

  public init(
    phase: PetWakeRitualPhase,
    duration: TimeInterval
  ) {
    self.phase = phase
    self.duration = duration
  }
}

public enum PetWakeRitualPlanner {
  public static func steps(
    timing: PetWakeRitualTiming = .standard,
    reduceMotion: Bool
  ) -> [PetWakeRitualStep] {
    if reduceMotion {
      return [
        PetWakeRitualStep(
          phase: .orienting,
          duration: timing.reducedMotionDuration
        )
      ]
    }
    return [
      PetWakeRitualStep(
        phase: .stretching,
        duration: timing.stretchDuration
      ),
      PetWakeRitualStep(
        phase: .orienting,
        duration: timing.orientDuration
      ),
    ]
  }
}
