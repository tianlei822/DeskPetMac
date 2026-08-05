import DeskPetCore
import Foundation
import Testing

@testable import DeskPetMac

@MainActor
private final class RecordingPetSoundPlayer: PetSoundPlaying {
  private(set) var profiles: [PetSoundProfile] = []
  private(set) var stopCount = 0

  func play(_ profile: PetSoundProfile) {
    profiles.append(profile)
  }

  func stop() {
    stopCount += 1
  }
}

@MainActor
private final class RecordingPetHapticPlayer: PetHapticFeedbackPlaying {
  private(set) var performanceCount = 0

  func perform() {
    performanceCount += 1
  }
}

@Suite("Pet haptic feedback")
struct PetHapticFeedbackTests {
  @Test("direct cues are tactile while passive greetings stay quiet")
  func directCuePolicyIsRestrained() {
    for cue in PetSoundCue.allCases where cue != .greeting {
      #expect(PetHapticDesign.performsFeedback(for: cue))
    }
    #expect(!PetHapticDesign.performsFeedback(for: .greeting))
  }

  @Test("interaction feedback remains opt-in")
  @MainActor
  func feedbackDefaultsToOff() throws {
    let fixture = try makeFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

    fixture.model.pat()

    #expect(fixture.soundPlayer.profiles.isEmpty)
    #expect(fixture.hapticPlayer.performanceCount == 0)
  }

  @Test("enabled direct interactions play sound and one tactile pulse")
  @MainActor
  func enabledFeedbackPerformsTogether() throws {
    let fixture = try makeFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    fixture.model.isSoundEnabled = true

    fixture.model.interact(at: .noseOrSensor)
    fixture.model.handleStroke(.scratch(.earOrTemple))

    #expect(fixture.soundPlayer.profiles.count == 2)
    #expect(fixture.hapticPlayer.performanceCount == 2)
  }

  @Test("Quiet Mode suppresses both channels")
  @MainActor
  func quietModeSuppressesFeedback() throws {
    let fixture = try makeFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    fixture.model.isSoundEnabled = true
    fixture.model.isQuietModeEnabled = true

    fixture.model.interact(at: .noseOrSensor)

    #expect(fixture.soundPlayer.profiles.isEmpty)
    #expect(fixture.hapticPlayer.performanceCount == 0)
  }

  @Test("a pet-selection greeting never taps the trackpad")
  @MainActor
  func greetingDoesNotPerformHapticFeedback() throws {
    let fixture = try makeFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    fixture.model.isSoundEnabled = true

    fixture.model.selectPetKind(.dog)

    #expect(fixture.soundPlayer.profiles.count == 1)
    #expect(fixture.hapticPlayer.performanceCount == 0)
  }

  @MainActor
  private func makeFixture() throws -> (
    model: PetViewModel,
    soundPlayer: RecordingPetSoundPlayer,
    hapticPlayer: RecordingPetHapticPlayer,
    defaults: UserDefaults,
    suiteName: String
  ) {
    let suiteName = "PetHapticFeedbackTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let soundPlayer = RecordingPetSoundPlayer()
    let hapticPlayer = RecordingPetHapticPlayer()
    return (
      PetViewModel(
        defaults: defaults,
        postsReminderNotifications: false,
        soundPlayer: soundPlayer,
        hapticPlayer: hapticPlayer
      ),
      soundPlayer,
      hapticPlayer,
      defaults,
      suiteName
    )
  }
}
