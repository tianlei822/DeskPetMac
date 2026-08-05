import Foundation

public enum PetGreetingPresentation: Equatable, Sendable {
  case callout
  case personalityMoment
}

public struct PetGreetingRitualContext: Equatable, Sendable {
  public let greeting: PetGreeting
  public let petKind: PetKind
  public let displayName: String
  public let familiarity: Double

  public init(
    greeting: PetGreeting,
    petKind: PetKind,
    displayName: String,
    familiarity: Double
  ) {
    self.greeting = greeting
    self.petKind = petKind
    let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.displayName = name.isEmpty ? petKind.displayName : String(name.prefix(24))
    self.familiarity =
      familiarity.isFinite
      ? min(1, max(0, familiarity))
      : 0
  }
}

public struct PetGreetingRitual: Equatable, Sendable {
  public let presentation: PetGreetingPresentation
  public let line: String
  public let pose: PersonalityPose?
  public let duration: TimeInterval
  public let playsAffectionPulse: Bool
  public let heartPulseDelays: [TimeInterval]

  public init(
    presentation: PetGreetingPresentation,
    line: String,
    pose: PersonalityPose?,
    duration: TimeInterval,
    playsAffectionPulse: Bool,
    heartPulseDelays: [TimeInterval]
  ) {
    self.presentation = presentation
    self.line = line
    self.pose = pose
    let resolvedDuration = min(5, max(0.6, duration.isFinite ? duration : 2.5))
    self.duration = resolvedDuration
    self.playsAffectionPulse = playsAffectionPulse
    self.heartPulseDelays =
      heartPulseDelays
      .filter { $0.isFinite && $0 >= 0 && $0 < resolvedDuration }
      .sorted()
  }
}

public enum PetGreetingRitualPlanner {
  public static func ritual(
    for context: PetGreetingRitualContext
  ) -> PetGreetingRitual {
    switch context.greeting {
    case .firstMeeting:
      PetGreetingRitual(
        presentation: .personalityMoment,
        line: "Hi, I'm \(context.displayName)!",
        pose: .perk,
        duration: 3.0,
        playsAffectionPulse: false,
        heartPulseDelays: []
      )
    case .returningSoon:
      PetGreetingRitual(
        presentation: .callout,
        line: briefReturnLine(for: context.petKind),
        pose: nil,
        duration: 0.95,
        playsAffectionPulse: false,
        heartPulseDelays: []
      )
    case .welcomeBack:
      PetGreetingRitual(
        presentation: .personalityMoment,
        line: welcomeLine(for: context.petKind),
        pose: welcomePose(for: context.petKind),
        duration: 3.0,
        playsAffectionPulse: true,
        heartPulseDelays: context.familiarity >= 0.18 ? [0.32] : []
      )
    case .longTimeNoSee:
      PetGreetingRitual(
        presentation: .personalityMoment,
        line: reunionLine(for: context.petKind),
        pose: reunionPose(for: context.petKind),
        duration: 3.8,
        playsAffectionPulse: true,
        heartPulseDelays: context.familiarity >= 0.18
          ? [0.20, 0.82]
          : [0.35]
      )
    }
  }

  private static func briefReturnLine(for petKind: PetKind) -> String {
    switch petKind {
    case .cat:
      "Back already? I noticed."
    case .pauli:
      "Return interval: pleasantly short."
    case .dog:
      "You're back already!"
    }
  }

  private static func welcomeLine(for petKind: PetKind) -> String {
    switch petKind {
    case .cat:
      "Welcome back. Your spot was supervised."
    case .pauli:
      "Companion link restored."
    case .dog:
      "Welcome back! I saved you a wag."
    }
  }

  private static func reunionLine(for petKind: PetKind) -> String {
    switch petKind {
    case .cat:
      "I did not wait by the door. Much."
    case .pauli:
      "Companion link restored. I missed this."
    case .dog:
      "I missed you so much!"
    }
  }

  private static func welcomePose(for petKind: PetKind) -> PersonalityPose {
    switch petKind {
    case .cat:
      .peek
    case .pauli, .dog:
      .perk
    }
  }

  private static func reunionPose(for petKind: PetKind) -> PersonalityPose {
    switch petKind {
    case .cat:
      .stretch
    case .pauli, .dog:
      .proud
    }
  }
}
