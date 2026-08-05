import Foundation

public struct PetAttentionPhase: Equatable, Sendable {
  public let eyeProgress: Double
  public let earProgress: Double
  public let headProgress: Double
  public let bodyProgress: Double

  public init(
    eyeProgress: Double,
    earProgress: Double,
    headProgress: Double,
    bodyProgress: Double
  ) {
    self.eyeProgress = eyeProgress
    self.earProgress = earProgress
    self.headProgress = headProgress
    self.bodyProgress = bodyProgress
  }

  public static let neutral = PetAttentionPhase(
    eyeProgress: 0,
    earProgress: 0,
    headProgress: 0,
    bodyProgress: 0
  )

  public static let settled = PetAttentionPhase(
    eyeProgress: 1,
    earProgress: 1,
    headProgress: 1,
    bodyProgress: 1
  )

  public var usesCuriousArtwork: Bool {
    headProgress >= 0.2
  }
}

public enum PetAttentionTimeline {
  private struct Stage {
    let delay: TimeInterval
    let duration: TimeInterval
  }

  private struct Tuning {
    let eye: Stage
    let ear: Stage
    let head: Stage
    let body: Stage
  }

  public static func phase(
    for pet: PetKind,
    elapsed: TimeInterval,
    reduceMotion: Bool
  ) -> PetAttentionPhase {
    if reduceMotion { return .settled }
    guard elapsed.isFinite, elapsed >= 0 else { return .neutral }

    let tuning = tuning(for: pet)
    return PetAttentionPhase(
      eyeProgress: progress(elapsed: elapsed, stage: tuning.eye),
      earProgress: progress(elapsed: elapsed, stage: tuning.ear),
      headProgress: progress(elapsed: elapsed, stage: tuning.head),
      bodyProgress: progress(elapsed: elapsed, stage: tuning.body)
    )
  }

  private static func tuning(for pet: PetKind) -> Tuning {
    switch pet {
    case .cat:
      Tuning(
        eye: Stage(delay: 0, duration: 0.09),
        ear: Stage(delay: 0.06, duration: 0.14),
        head: Stage(delay: 0.18, duration: 0.22),
        body: Stage(delay: 0.34, duration: 0.28)
      )
    case .pauli:
      Tuning(
        eye: Stage(delay: 0, duration: 0.07),
        ear: Stage(delay: 0.08, duration: 0.18),
        head: Stage(delay: 0.22, duration: 0.20),
        body: Stage(delay: 0.38, duration: 0.24)
      )
    case .dog:
      Tuning(
        eye: Stage(delay: 0, duration: 0.08),
        ear: Stage(delay: 0.04, duration: 0.12),
        head: Stage(delay: 0.14, duration: 0.18),
        body: Stage(delay: 0.26, duration: 0.26)
      )
    }
  }

  private static func progress(
    elapsed: TimeInterval,
    stage: Stage
  ) -> Double {
    guard elapsed > stage.delay else { return 0 }
    let raw = min(1, (elapsed - stage.delay) / stage.duration)
    return raw * raw * (3 - 2 * raw)
  }
}

public struct PetAttentionSample: Equatable, Sendable {
  public let offset: CGSize
  public let elapsed: TimeInterval

  public init(offset: CGSize, elapsed: TimeInterval) {
    self.offset = offset
    self.elapsed = elapsed
  }
}

public struct PetAttentionTracker: Sendable {
  public private(set) var currentOffset: CGSize?
  private var startedAt: TimeInterval?

  public init() {}

  public mutating func observe(
    offset: CGSize?,
    at time: TimeInterval
  ) {
    guard time.isFinite,
          let offset,
          offset.width.isFinite,
          offset.height.isFinite else {
      currentOffset = nil
      startedAt = nil
      return
    }

    let safeOffset = CGSize(
      width: min(1, max(-1, offset.width)),
      height: min(1, max(-1, offset.height))
    )
    if currentOffset == nil {
      startedAt = time
    }
    currentOffset = safeOffset
  }

  public func sample(at time: TimeInterval) -> PetAttentionSample? {
    guard time.isFinite,
          let currentOffset,
          let startedAt else { return nil }
    return PetAttentionSample(
      offset: currentOffset,
      elapsed: max(0, time - startedAt)
    )
  }
}
