import CoreGraphics
import DeskPetCore

struct PetDisplayIdentity: Equatable {
  let id: String
  let legacyIDs: [String]

  static func resolve(
    stableID: String?,
    legacyID: String?,
    localizedName: String
  ) -> PetDisplayIdentity {
    if let stableID, !stableID.isEmpty {
      let aliases =
        legacyID.flatMap { $0 == stableID ? nil : [$0] }
        ?? (localizedName == stableID ? [] : [localizedName])
      return PetDisplayIdentity(id: stableID, legacyIDs: aliases)
    }
    if let legacyID, !legacyID.isEmpty {
      return PetDisplayIdentity(id: legacyID, legacyIDs: [])
    }
    return PetDisplayIdentity(id: localizedName, legacyIDs: [])
  }
}

struct PetWindowScreenSnapshot: Equatable {
  let id: String
  let legacyIDs: [String]
  let visibleFrame: CGRect

  func matches(_ screenID: String) -> Bool {
    id == screenID || legacyIDs.contains(screenID)
  }
}

struct PetWindowPlacement: Equatable {
  let screenID: String
  let anchor: PetWindowAnchor
  let origin: CGPoint
}

enum PetWindowPlacementResolver {
  static func resolve(
    windowFrame: CGRect,
    windowSize: CGSize,
    screens: [PetWindowScreenSnapshot],
    preferredScreenID: String?,
    mainScreenID: String?,
    anchorsByScreenID: [String: PetWindowAnchor],
    fallbackAnchor: PetWindowAnchor?
  ) -> PetWindowPlacement? {
    let usableScreens = screens.filter { $0.visibleFrame.isFiniteAndNonEmpty }
    guard !usableScreens.isEmpty else { return nil }

    let target =
      preferredScreenID.flatMap { preferredScreenID in
        usableScreens.first { $0.matches(preferredScreenID) }
      } ?? overlapTarget(
        windowFrame: windowFrame,
        screens: preferredScreenID == nil ? [] : usableScreens
      ) ?? mainScreenID.flatMap { mainScreenID in
        usableScreens.first { $0.matches(mainScreenID) }
      } ?? usableScreens[0]

    let anchor = anchorsByScreenID[target.id] ?? fallbackAnchor ?? .default
    return PetWindowPlacement(
      screenID: target.id,
      anchor: anchor,
      origin: anchor.resolve(
        windowSize: windowSize,
        visibleFrame: target.visibleFrame
      )
    )
  }

  private static func overlapTarget(
    windowFrame: CGRect,
    screens: [PetWindowScreenSnapshot]
  ) -> PetWindowScreenSnapshot? {
    guard windowFrame.isFiniteAndNonEmpty else { return nil }

    var best: (screen: PetWindowScreenSnapshot, area: CGFloat)?
    for screen in screens {
      let intersection = windowFrame.intersection(screen.visibleFrame)
      let area = intersection.isNull ? 0 : intersection.width * intersection.height
      if area > (best?.area ?? 0) {
        best = (screen, area)
      }
    }
    return best?.screen
  }
}

extension CGRect {
  fileprivate var isFiniteAndNonEmpty: Bool {
    [minX, minY, width, height].allSatisfy(\.isFinite)
      && width > 0
      && height > 0
  }
}
