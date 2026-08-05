import SwiftUI
import Testing

@testable import DeskPetMac

@Suite("Pet accessibility contrast")
struct PetAccessibilityContrastTests {
  @Test("increased contrast strengthens every structural token")
  func increasedContrastStrengthensSurfaces() {
    let standard = PetAccessibilityContrastStyle.resolve(
      systemContrast: .standard,
      override: nil
    )
    let increased = PetAccessibilityContrastStyle.resolve(
      systemContrast: .increased,
      override: nil
    )

    #expect(!standard.isIncreased)
    #expect(increased.isIncreased)
    #expect(
      increased.surfaceBorderOpacityMultiplier
        > standard.surfaceBorderOpacityMultiplier
    )
    #expect(increased.surfaceBorderWidth > standard.surfaceBorderWidth)
    #expect(increased.shadowOpacityMultiplier > standard.shadowOpacityMultiplier)
    #expect(increased.selectedFillOpacity > standard.selectedFillOpacity)
    #expect(increased.unselectedFillOpacity > standard.unselectedFillOpacity)
    #expect(increased.usesPrimarySupportingText)
    #expect(increased.usesDarkButtonLabel)
  }

  @Test("a deterministic visual override wins over the host setting")
  func visualOverrideWins() {
    let forcedStandard = PetAccessibilityContrastStyle.resolve(
      systemContrast: .increased,
      override: .standard
    )
    let forcedIncreased = PetAccessibilityContrastStyle.resolve(
      systemContrast: .standard,
      override: .increased
    )

    #expect(!forcedStandard.isIncreased)
    #expect(forcedIncreased.isIncreased)
  }
}
