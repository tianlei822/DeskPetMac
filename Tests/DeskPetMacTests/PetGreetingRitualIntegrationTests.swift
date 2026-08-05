import DeskPetCore
import Foundation
import Testing

@testable import DeskPetMac

@Suite("Pet greeting ritual integration")
struct PetGreetingRitualIntegrationTests {
  @Test("a long absence presents the companion-specific reunion")
  @MainActor
  func longAbsencePresentsReunion() throws {
    let fixture = try makeFixture(
      petKind: .dog,
      lastSeenAt: Date().addingTimeInterval(-8 * 24 * 60 * 60),
      familiarity: 0.8
    )
    defer { fixture.cleanup() }

    fixture.model.selectPetKind(.dog)

    let moment = try #require(fixture.model.activePersonalityMoment)
    #expect(moment.id == "greeting.dog.long-time-no-see")
    #expect(moment.petKind == .dog)
    #expect(moment.pose == .proud)
    #expect(fixture.model.activeActivity.kind == .personality)
    #expect(!fixture.model.isStatusVisible)
    #expect(fixture.model.affectionPulse == 1)
  }

  @Test("a brief return stays lightweight")
  @MainActor
  func briefReturnStaysLightweight() throws {
    let fixture = try makeFixture(
      petKind: .dog,
      lastSeenAt: Date().addingTimeInterval(-30 * 60),
      familiarity: 0.8
    )
    defer { fixture.cleanup() }

    fixture.model.selectPetKind(.dog)

    #expect(fixture.model.activePersonalityMoment == nil)
    #expect(fixture.model.interactionCallout == "You're back already!")
    #expect(fixture.model.isStatusVisible)
    #expect(fixture.model.affectionPulse == 0)
  }

  @Test("direct interaction interrupts delayed reunion hearts")
  @MainActor
  func interactionInterruptsDelayedHearts() async throws {
    let fixture = try makeFixture(
      petKind: .dog,
      lastSeenAt: Date().addingTimeInterval(-8 * 24 * 60 * 60),
      familiarity: 0.8
    )
    defer { fixture.cleanup() }
    fixture.model.selectPetKind(.dog)

    fixture.model.dance()
    let heartBurstAfterDance = fixture.model.heartBurst
    try await Task.sleep(for: .milliseconds(900))

    #expect(fixture.model.activePersonalityMoment == nil)
    #expect(fixture.model.isDancing)
    #expect(fixture.model.heartBurst == heartBurstAfterDance)
  }

  @MainActor
  private func makeFixture(
    petKind: PetKind,
    lastSeenAt: Date,
    familiarity: Double
  ) throws -> GreetingFixture {
    let suiteName = "PetGreetingRitualIntegrationTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    var memories = PetMemoryCollection()
    memories[petKind] = PetMemory(
      lastSeenAt: lastSeenAt,
      familiarity: familiarity
    )
    defaults.set(
      try JSONEncoder().encode(memories),
      forKey: "deskpet.memories"
    )
    return GreetingFixture(
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
private struct GreetingFixture {
  let model: PetViewModel
  let defaults: UserDefaults
  let suiteName: String

  func cleanup() {
    defaults.removePersistentDomain(forName: suiteName)
  }
}
