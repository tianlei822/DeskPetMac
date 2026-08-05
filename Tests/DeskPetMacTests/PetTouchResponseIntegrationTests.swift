import DeskPetCore
import Foundation
import Testing

@testable import DeskPetMac

@Suite("Pet contextual touch response integration")
struct PetTouchResponseIntegrationTests {
  @Test("all direct-touch gestures share the affection pulse render path")
  @MainActor
  func directTouchGesturesShareAffectionPulse() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }
    let initialPulse = fixture.model.affectionPulse

    fixture.model.pat()
    #expect(fixture.model.affectionPulse == initialPulse + 1)

    fixture.model.interact(at: .noseOrSensor)
    #expect(fixture.model.affectionPulse == initialPulse + 2)

    fixture.model.handleStroke(.scratch(.earOrTemple))
    #expect(fixture.model.affectionPulse == initialPulse + 3)

    fixture.model.handleStroke(
      .swipe(direction: .right, intensity: 0.8)
    )
    #expect(fixture.model.affectionPulse == initialPulse + 4)
  }

  @Test("booping a sleeping companion uses its drowsy voice")
  @MainActor
  func sleepInterruptionUsesDrowsyVoice() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }
    fixture.model.observeIdleState(idleSeconds: 91)

    fixture.model.interact(at: .noseOrSensor)

    #expect(!fixture.model.isSleeping)
    #expect(fixture.model.interactionCallout == "Mm… awake now.")
  }

  @Test("a familiar fast swipe earns one restrained heart")
  @MainActor
  func familiarFastSwipeAddsHeart() throws {
    let fixture = try makeFixture(
      memory: PetMemory(
        bond: PetBond(points: 140),
        familiarity: 0.7
      )
    )
    defer { fixture.cleanup() }

    fixture.model.handleStroke(
      .swipe(direction: .right, intensity: 0.95)
    )

    #expect(fixture.model.interactionCallout == "Easy—my coat!")
    #expect(fixture.model.heartBurst == 1)
  }

  @Test("a new friend's gentle swipe remains subtle")
  @MainActor
  func newFriendGentleSwipeStaysSubtle() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }

    fixture.model.handleStroke(
      .swipe(direction: .right, intensity: 0.25)
    )

    #expect(fixture.model.interactionCallout == "Soft ruffle.")
    #expect(fixture.model.heartBurst == 0)
  }

  @Test("a five-pat combo earns a character response")
  @MainActor
  func patComboOpensCallout() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }

    for _ in 0..<5 {
      fixture.model.pat()
    }

    #expect(fixture.model.comboCount == 5)
    #expect(fixture.model.interactionCallout == "All right—excellent.")
  }

  @MainActor
  private func makeFixture(
    memory: PetMemory = PetMemory()
  ) throws -> TouchFixture {
    let suiteName = "PetTouchResponseIntegrationTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    var memories = PetMemoryCollection()
    memories[.cat] = memory
    defaults.set(
      try JSONEncoder().encode(memories),
      forKey: "deskpet.memories"
    )
    return TouchFixture(
      model: PetViewModel(
        defaults: defaults,
        postsReminderNotifications: false
      ),
      defaults: defaults,
      suiteName: suiteName
    )
  }
}

@MainActor
private struct TouchFixture {
  let model: PetViewModel
  let defaults: UserDefaults
  let suiteName: String

  func cleanup() {
    defaults.removePersistentDomain(forName: suiteName)
  }
}
