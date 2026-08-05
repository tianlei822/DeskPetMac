import Foundation

public struct PetRootTransitionPose: Equatable, Sendable {
  public let horizontalScale: Double
  public let verticalScale: Double
  public let horizontalOffset: Double
  public let verticalOffset: Double
  public let tiltDegrees: Double
  public let shadowScale: Double
  public let shadowOffset: Double

  public static let neutral = PetRootTransitionPose(
    horizontalScale: 1,
    verticalScale: 1,
    horizontalOffset: 0,
    verticalOffset: 0,
    tiltDegrees: 0,
    shadowScale: 1,
    shadowOffset: 0
  )
}

public enum PetRootTransitionMotion {
  public static func pose(
    for frame: PetRootMotionFrame,
    reduceMotion: Bool
  ) -> PetRootTransitionPose {
    guard !reduceMotion else { return .neutral }

    let progress = smoothStep(frame.phaseProgress)
    let direction = Double(frame.direction.rawValue)
    let noticeEnd = PetRootTransitionPose(
      horizontalScale: 1,
      verticalScale: 1,
      horizontalOffset: direction * 0.6,
      verticalOffset: -0.3,
      tiltDegrees: direction * 0.8,
      shadowScale: 0.99,
      shadowOffset: direction * 0.2
    )
    let anticipateEnd = PetRootTransitionPose(
      horizontalScale: 1.025,
      verticalScale: 0.965,
      horizontalOffset: -direction * 2.4,
      verticalOffset: 2.2,
      tiltDegrees: -direction * 2.4,
      shadowScale: 1.08,
      shadowOffset: -direction * 0.8
    )
    let slowingEnd = PetRootTransitionPose(
      horizontalScale: 1.01,
      verticalScale: 0.985,
      horizontalOffset: direction * 1.4,
      verticalOffset: 1,
      tiltDegrees: -direction * 1.2,
      shadowScale: 1.04,
      shadowOffset: direction * 0.5
    )

    switch frame.phase {
    case .notice:
      return interpolate(from: .neutral, to: noticeEnd, progress: progress)
    case .anticipate:
      return interpolate(from: noticeEnd, to: anticipateEnd, progress: progress)
    case .turning:
      return turningPose(
        from: anticipateEnd,
        progress: progress,
        rawProgress: safeProgress(frame.phaseProgress),
        direction: direction
      )
    case .walking:
      return .neutral
    case .slowing:
      return interpolate(from: .neutral, to: slowingEnd, progress: progress)
    case .settling:
      return settlingPose(
        from: slowingEnd,
        progress: progress,
        rawProgress: safeProgress(frame.phaseProgress),
        direction: direction
      )
    case .completed:
      return .neutral
    }
  }

  private static func turningPose(
    from start: PetRootTransitionPose,
    progress: Double,
    rawProgress: Double,
    direction: Double
  ) -> PetRootTransitionPose {
    let base = interpolate(from: start, to: .neutral, progress: progress)
    let arc = sin(rawProgress * .pi)
    return PetRootTransitionPose(
      horizontalScale: base.horizontalScale,
      verticalScale: base.verticalScale,
      horizontalOffset: base.horizontalOffset + direction * arc * 0.45,
      verticalOffset: base.verticalOffset - arc * 0.65,
      tiltDegrees: base.tiltDegrees + direction * arc * 0.35,
      shadowScale: base.shadowScale - arc * 0.012,
      shadowOffset: base.shadowOffset
    )
  }

  private static func settlingPose(
    from start: PetRootTransitionPose,
    progress: Double,
    rawProgress: Double,
    direction: Double
  ) -> PetRootTransitionPose {
    let base = interpolate(from: start, to: .neutral, progress: progress)
    let rebound = sin(rawProgress * .pi)
    return PetRootTransitionPose(
      horizontalScale: base.horizontalScale,
      verticalScale: base.verticalScale + rebound * 0.004,
      horizontalOffset: base.horizontalOffset + direction * rebound * 0.35,
      verticalOffset: base.verticalOffset - rebound * 0.8,
      tiltDegrees: base.tiltDegrees + direction * rebound * 0.25,
      shadowScale: base.shadowScale - rebound * 0.015,
      shadowOffset: base.shadowOffset
    )
  }

  private static func interpolate(
    from start: PetRootTransitionPose,
    to end: PetRootTransitionPose,
    progress: Double
  ) -> PetRootTransitionPose {
    PetRootTransitionPose(
      horizontalScale: mix(start.horizontalScale, end.horizontalScale, progress),
      verticalScale: mix(start.verticalScale, end.verticalScale, progress),
      horizontalOffset: mix(start.horizontalOffset, end.horizontalOffset, progress),
      verticalOffset: mix(start.verticalOffset, end.verticalOffset, progress),
      tiltDegrees: mix(start.tiltDegrees, end.tiltDegrees, progress),
      shadowScale: mix(start.shadowScale, end.shadowScale, progress),
      shadowOffset: mix(start.shadowOffset, end.shadowOffset, progress)
    )
  }

  private static func mix(_ start: Double, _ end: Double, _ progress: Double) -> Double {
    start + (end - start) * progress
  }

  private static func smoothStep(_ value: Double) -> Double {
    let progress = safeProgress(value)
    return progress * progress * (3 - 2 * progress)
  }

  private static func safeProgress(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }
}
