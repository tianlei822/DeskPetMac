import DeskPetCore
import Foundation
import Testing

@testable import DeskPetMac

@Suite("Pet wake ritual integration")
struct PetWakeRitualIntegrationTests {
  @Test("idle observations enter sleep and trigger wake on return")
  @MainActor
  func idleReturnTriggersWakeRitual() throws {
    let fixture = try makeFixture(reduceMotion: false)
    defer { fixture.cleanup() }

    fixture.model.observeIdleState(idleSeconds: 91)
    #expect(fixture.model.isSleeping)
    #expect(fixture.model.activeActivity.kind == .sleeping)

    fixture.model.observeIdleState(idleSeconds: 0)
    #expect(!fixture.model.isSleeping)
    #expect(fixture.model.wakeRitualPhase == .stretching)
    #expect(fixture.model.activeActivity.kind == .waking)

    fixture.model.dance()
  }

  @Test("passive return stretches, orients, then becomes ready")
  @MainActor
  func passiveReturnRunsCausalSequence() async throws {
    let fixture = try makeFixture(reduceMotion: false)
    defer { fixture.cleanup() }

    fixture.model.beginWakeRitual()

    #expect(fixture.model.wakeRitualPhase == .stretching)
    #expect(fixture.model.activeActivity.kind == .waking)
    #expect(fixture.model.activeActivity.personalityPose == .stretch)
    #expect(fixture.model.activePersonalityMoment == nil)
    #expect(fixture.model.interactionCallout == nil)

    try await waitForPhase(.orienting, in: fixture.model)
    #expect(fixture.model.wakeRitualPhase == .orienting)
    #expect(fixture.model.activeActivity.personalityPose == .perk)

    try await waitForPhase(nil, in: fixture.model)
    #expect(fixture.model.wakeRitualPhase == nil)
    #expect(fixture.model.activeActivity.kind == .autonomous)
  }

  @Test("Reduce Motion skips the stretch stage")
  @MainActor
  func reducedMotionUsesOneStage() async throws {
    let fixture = try makeFixture(reduceMotion: true)
    defer { fixture.cleanup() }

    fixture.model.beginWakeRitual()

    #expect(fixture.model.wakeRitualPhase == .orienting)
    #expect(fixture.model.activeActivity.personalityPose == .perk)
    try await waitForPhase(nil, in: fixture.model)
    #expect(fixture.model.wakeRitualPhase == nil)
  }

  @Test("direct interaction cancels every remaining wake step")
  @MainActor
  func interactionInterruptsWake() async throws {
    let fixture = try makeFixture(reduceMotion: false)
    defer { fixture.cleanup() }
    fixture.model.beginWakeRitual()

    fixture.model.dance()

    #expect(fixture.model.wakeRitualPhase == nil)
    #expect(fixture.model.activeActivity.kind == .dancing)
    try await Task.sleep(for: .milliseconds(150))
    #expect(fixture.model.wakeRitualPhase == nil)
    #expect(fixture.model.activeActivity.kind == .dancing)
  }

  @MainActor
  private func makeFixture(reduceMotion: Bool) throws -> WakeFixture {
    let suiteName = "PetWakeRitualIntegrationTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let timing = PetWakeRitualTiming(
      stretchDuration: 0.05,
      orientDuration: 0.05,
      reducedMotionDuration: 0.05
    )
    return WakeFixture(
      model: PetViewModel(
        defaults: defaults,
        postsReminderNotifications: false,
        wakeRitualTiming: timing,
        wakeReduceMotionProvider: { reduceMotion }
      ),
      defaults: defaults,
      suiteName: suiteName
    )
  }

  @MainActor
  private func waitForPhase(
    _ expected: PetWakeRitualPhase?,
    in model: PetViewModel
  ) async throws {
    for _ in 0..<100 {
      if model.wakeRitualPhase == expected { return }
      try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record(
      "Timed out waiting for wake phase \(String(describing: expected))"
    )
  }
}

@MainActor
private struct WakeFixture {
  let model: PetViewModel
  let defaults: UserDefaults
  let suiteName: String

  func cleanup() {
    defaults.removePersistentDomain(forName: suiteName)
  }
}
