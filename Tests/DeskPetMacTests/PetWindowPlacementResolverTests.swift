import CoreGraphics
import DeskPetCore
import Foundation
import Testing

@testable import DeskPetMac

@Suite("Pet display identity")
struct PetDisplayIdentityTests {
  @Test("stable display UUID wins while the old number remains an alias")
  func stableIdentityKeepsLegacyAlias() {
    let identity = PetDisplayIdentity.resolve(
      stableID: "display-uuid",
      legacyID: "42",
      localizedName: "Studio Display"
    )

    #expect(identity.id == "display-uuid")
    #expect(identity.legacyIDs == ["42"])
  }

  @Test("display number and localized name are safe fallbacks")
  func identityFallbacksAreStable() {
    #expect(
      PetDisplayIdentity.resolve(
        stableID: nil,
        legacyID: "42",
        localizedName: "Studio Display"
      ) == PetDisplayIdentity(id: "42", legacyIDs: []))
    #expect(
      PetDisplayIdentity.resolve(
        stableID: nil,
        legacyID: nil,
        localizedName: "Built-in Display"
      ) == PetDisplayIdentity(id: "Built-in Display", legacyIDs: []))
  }
}

@Suite("Pet window placement resolver")
struct PetWindowPlacementResolverTests {
  private let windowSize = CGSize(width: 260, height: 290)

  @Test("a resized preferred display keeps its normalized anchor")
  func resizedPreferredDisplayKeepsAnchor() throws {
    let screen = PetWindowScreenSnapshot(
      id: "display-a",
      legacyIDs: [],
      visibleFrame: CGRect(x: 100, y: 40, width: 1_400, height: 900)
    )
    let anchor = PetWindowAnchor(horizontal: 0.25, vertical: 0.70)

    let placement = try #require(
      PetWindowPlacementResolver.resolve(
        windowFrame: CGRect(x: 400, y: 300, width: 260, height: 290),
        windowSize: windowSize,
        screens: [screen],
        preferredScreenID: "display-a",
        mainScreenID: "display-a",
        anchorsByScreenID: ["display-a": anchor],
        fallbackAnchor: nil
      ))

    #expect(placement.screenID == "display-a")
    #expect(
      placement.origin
        == anchor.resolve(
          windowSize: windowSize,
          visibleFrame: screen.visibleFrame
        ))
  }

  @Test("a removed display carries its relative position to the fallback")
  func removedDisplayCarriesRelativePosition() throws {
    let main = PetWindowScreenSnapshot(
      id: "main",
      legacyIDs: [],
      visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
    )
    let removedAnchor = PetWindowAnchor(horizontal: 0.82, vertical: 0.18)

    let placement = try #require(
      PetWindowPlacementResolver.resolve(
        windowFrame: CGRect(x: 2_100, y: 120, width: 260, height: 290),
        windowSize: windowSize,
        screens: [main],
        preferredScreenID: "removed",
        mainScreenID: "main",
        anchorsByScreenID: [:],
        fallbackAnchor: removedAnchor
      ))

    #expect(placement.screenID == "main")
    #expect(
      placement.origin
        == removedAnchor.resolve(
          windowSize: windowSize,
          visibleFrame: main.visibleFrame
        ))
  }

  @Test("a fallback display's own memory wins over the removed display")
  func fallbackDisplayMemoryWins() throws {
    let main = PetWindowScreenSnapshot(
      id: "main",
      legacyIDs: [],
      visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
    )
    let mainAnchor = PetWindowAnchor(horizontal: 0.16, vertical: 0.68)

    let placement = try #require(
      PetWindowPlacementResolver.resolve(
        windowFrame: CGRect(x: 2_100, y: 120, width: 260, height: 290),
        windowSize: windowSize,
        screens: [main],
        preferredScreenID: "removed",
        mainScreenID: "main",
        anchorsByScreenID: ["main": mainAnchor],
        fallbackAnchor: PetWindowAnchor(horizontal: 0.82, vertical: 0.18)
      ))

    #expect(
      placement.origin
        == mainAnchor.resolve(
          windowSize: windowSize,
          visibleFrame: main.visibleFrame
        ))
  }

  @Test("a legacy display number still matches its stable identity")
  func legacyDisplayIdentityMatches() throws {
    let screen = PetWindowScreenSnapshot(
      id: "display-uuid",
      legacyIDs: ["42"],
      visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
    )

    let placement = try #require(
      PetWindowPlacementResolver.resolve(
        windowFrame: CGRect(x: 100, y: 100, width: 260, height: 290),
        windowSize: windowSize,
        screens: [screen],
        preferredScreenID: "42",
        mainScreenID: "display-uuid",
        anchorsByScreenID: ["display-uuid": .default],
        fallbackAnchor: nil
      ))

    #expect(placement.screenID == "display-uuid")
  }

  @Test("an unavailable preferred display chooses the current overlap")
  func unavailableDisplayChoosesCurrentOverlap() throws {
    let main = PetWindowScreenSnapshot(
      id: "main",
      legacyIDs: [],
      visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
    )
    let secondary = PetWindowScreenSnapshot(
      id: "secondary",
      legacyIDs: [],
      visibleFrame: CGRect(x: 1_440, y: 0, width: 1_920, height: 1_080)
    )

    let placement = try #require(
      PetWindowPlacementResolver.resolve(
        windowFrame: CGRect(x: 1_600, y: 200, width: 260, height: 290),
        windowSize: windowSize,
        screens: [main, secondary],
        preferredScreenID: "removed",
        mainScreenID: "main",
        anchorsByScreenID: [:],
        fallbackAnchor: .default
      ))

    #expect(placement.screenID == "secondary")
  }
}

@Suite("Pet window position migration")
struct PetWindowPositionMigrationTests {
  @Test("a legacy display anchor migrates to the stable display ID")
  func legacyAnchorMigrates() throws {
    let suiteName = "PetWindowPositionMigrationTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = PetWindowPositionStore(defaults: defaults)
    let anchor = PetWindowAnchor(horizontal: 0.34, vertical: 0.61)
    store.save(anchor: anchor, screenID: "42")

    let migrated = store.anchor(
      for: "display-uuid",
      legacyScreenIDs: ["42"]
    )

    #expect(migrated == anchor)
    #expect(store.anchor(for: "display-uuid") == anchor)
    #expect(store.lastScreenID == "display-uuid")
  }
}
