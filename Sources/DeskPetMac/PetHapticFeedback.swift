import AppKit
import DeskPetCore

enum PetHapticDesign {
  static func performsFeedback(for cue: PetSoundCue) -> Bool {
    switch cue {
    case .pat, .boop, .scratch, .swipe, .toy, .treatSatisfied:
      true
    case .greeting:
      false
    }
  }
}

@MainActor
protocol PetHapticFeedbackPlaying: AnyObject {
  func perform()
}

@MainActor
final class PetHapticFeedbackPlayer: PetHapticFeedbackPlaying {
  func perform() {
    NSHapticFeedbackManager.defaultPerformer.perform(
      .generic,
      performanceTime: .drawCompleted
    )
  }
}
