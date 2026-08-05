public struct PetTransitionArtworkLayers: Equatable, Sendable {
  public let currentResourceName: String
  public let nextResourceName: String
  public let blend: Double

  public init(
    currentResourceName: String,
    nextResourceName: String,
    blend: Double
  ) {
    self.currentResourceName = currentResourceName
    self.nextResourceName = nextResourceName
    self.blend = blend
  }

  public var dominantResourceName: String {
    blend >= 0.5 ? nextResourceName : currentResourceName
  }
}

public enum PetTransitionArtworkResolver {
  public static func resolve(
    frame: PetTransitionArtworkFrame,
    availableResourceNames: Set<String>,
    baseFallbackResourceName: String
  ) -> PetTransitionArtworkLayers {
    let fallback = availableResourceNames.contains(frame.fallbackResourceName)
      ? frame.fallbackResourceName
      : baseFallbackResourceName
    let current = availableResourceNames.contains(frame.currentResourceName)
      ? frame.currentResourceName
      : fallback
    let next = availableResourceNames.contains(frame.nextResourceName)
      ? frame.nextResourceName
      : fallback
    let blend = current == next || !frame.blend.isFinite
      ? 0
      : min(1, max(0, frame.blend))
    return PetTransitionArtworkLayers(
      currentResourceName: current,
      nextResourceName: next,
      blend: blend
    )
  }
}
