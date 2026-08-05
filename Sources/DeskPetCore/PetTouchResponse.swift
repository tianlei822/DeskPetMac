public enum PetTouchAction: Equatable, Sendable {
  case pat(comboCount: Int)
  case boop
  case scratch(PetScratchRegion)
  case swipe(direction: PetSwipeDirection, intensity: Double)
}

public enum PetTouchResponseIntensity: Int, Equatable, Comparable, Sendable {
  case subtle
  case warm
  case delighted

  public static func < (
    lhs: PetTouchResponseIntensity,
    rhs: PetTouchResponseIntensity
  ) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

public struct PetTouchResponseContext: Equatable, Sendable {
  public let petKind: PetKind
  public let action: PetTouchAction
  public let mood: PetWeatherMood
  public let bondLevel: BondLevel
  public let familiarity: Double
  public let interruptedActivity: PetActivityKind

  public init(
    petKind: PetKind,
    action: PetTouchAction,
    mood: PetWeatherMood,
    bondLevel: BondLevel,
    familiarity: Double,
    interruptedActivity: PetActivityKind
  ) {
    self.petKind = petKind
    self.action = action
    self.mood = mood
    self.bondLevel = bondLevel
    self.familiarity =
      familiarity.isFinite
      ? min(1, max(0, familiarity))
      : 0
    self.interruptedActivity = interruptedActivity
  }
}

public struct PetTouchResponse: Equatable, Sendable {
  public let line: String
  public let intensity: PetTouchResponseIntensity
  public let presentsCallout: Bool
  public let addsHeart: Bool

  public init(
    line: String,
    intensity: PetTouchResponseIntensity,
    presentsCallout: Bool,
    addsHeart: Bool
  ) {
    self.line = line
    self.intensity = intensity
    self.presentsCallout = presentsCallout
    self.addsHeart = addsHeart
  }
}

public enum PetTouchResponsePlanner {
  public static func response(
    for context: PetTouchResponseContext
  ) -> PetTouchResponse {
    let isFamiliar =
      context.bondLevel >= .companion
      || context.familiarity >= 0.55
    let mode: ResponseMode
    if context.interruptedActivity == .sleeping
      || context.interruptedActivity == .waking
    {
      mode = .drowsy
    } else if context.mood == .stormy {
      mode = .stormComfort
    } else if isFamiliar {
      mode = .familiar
    } else {
      mode = .neutral
    }

    let intensity = intensity(
      for: context.action,
      isFamiliar: isFamiliar
    )
    let presentsCallout: Bool
    if case .pat(let comboCount) = context.action {
      presentsCallout = comboCount >= 5 || mode != .neutral
    } else {
      presentsCallout = true
    }
    let addsHeart: Bool
    if case .swipe(_, let rawIntensity) = context.action {
      addsHeart = safeUnit(rawIntensity) >= 0.75 && isFamiliar
    } else {
      addsHeart = false
    }

    return PetTouchResponse(
      line: line(
        for: context.petKind,
        action: context.action,
        mode: mode
      ),
      intensity: intensity,
      presentsCallout: presentsCallout,
      addsHeart: addsHeart
    )
  }

  private static func intensity(
    for action: PetTouchAction,
    isFamiliar: Bool
  ) -> PetTouchResponseIntensity {
    let base: PetTouchResponseIntensity =
      switch action {
      case .pat(let comboCount):
        comboCount >= 5 ? .delighted : (comboCount >= 2 ? .warm : .subtle)
      case .boop:
        .warm
      case .scratch:
        .warm
      case .swipe(_, let intensity):
        switch safeUnit(intensity) {
        case 0.75...:
          .delighted
        case 0.45...:
          .warm
        default:
          .subtle
        }
      }
    if isFamiliar, base == .warm { return .delighted }
    return base
  }

  private static func line(
    for petKind: PetKind,
    action: PetTouchAction,
    mode: ResponseMode
  ) -> String {
    switch mode {
    case .drowsy:
      drowsyLine(for: petKind)
    case .stormComfort:
      stormLine(for: petKind)
    case .familiar:
      familiarLine(for: petKind, action: action)
    case .neutral:
      neutralLine(for: petKind, action: action)
    }
  }

  private static func drowsyLine(for petKind: PetKind) -> String {
    switch petKind {
    case .cat:
      "Mm… awake now."
    case .pauli:
      "Wake sensors online."
    case .dog:
      "Oh! Hi, you're here!"
    }
  }

  private static func stormLine(for petKind: PetKind) -> String {
    switch petKind {
    case .cat:
      "Thunder truce."
    case .pauli:
      "Stability restored."
    case .dog:
      "I feel braver!"
    }
  }

  private static func familiarLine(
    for petKind: PetKind,
    action: PetTouchAction
  ) -> String {
    switch (petKind, action) {
    case (.cat, .pat):
      "You know the spot."
    case (.cat, .boop):
      "A trusted boop."
    case (.cat, .scratch(.earOrTemple)):
      "My ear—you remembered."
    case (.cat, .scratch(.chin)):
      "Yes, the chin."
    case (.cat, .swipe(_, let intensity)):
      safeUnit(intensity) >= 0.75 ? "Easy—my coat!" : "Familiar ruffle."

    case (.pauli, .pat):
      "Familiar pat pattern."
    case (.pauli, .boop):
      "Trusted sensor ping."
    case (.pauli, .scratch(.earOrTemple)):
      "Temple servo: perfect."
    case (.pauli, .scratch(.chin)):
      "Chin servo: perfect."
    case (.pauli, .swipe(_, let intensity)):
      safeUnit(intensity) >= 0.75 ? "Known fast vector." : "Known motion pattern."

    case (.dog, .pat):
      "Best pats, as always!"
    case (.dog, .boop):
      "My favorite boop!"
    case (.dog, .scratch(.earOrTemple)):
      "Yes—favorite spot!"
    case (.dog, .scratch(.chin)):
      "That's the spot!"
    case (.dog, .swipe(_, let intensity)):
      safeUnit(intensity) >= 0.75 ? "Best ruffle ever!" : "Nice and gentle!"
    }
  }

  private static func neutralLine(
    for petKind: PetKind,
    action: PetTouchAction
  ) -> String {
    switch (petKind, action) {
    case (.cat, .pat(let comboCount)):
      comboCount >= 5 ? "All right—excellent." : "mrrp."
    case (.cat, .boop):
      "boop!"
    case (.cat, .scratch(.earOrTemple)):
      "purr…"
    case (.cat, .scratch(.chin)):
      "mrrp…"
    case (.cat, .swipe(_, let intensity)):
      safeUnit(intensity) >= 0.75 ? "Hey—my fur!" : "Soft ruffle."

    case (.pauli, .pat(let comboCount)):
      comboCount >= 5 ? "Pat combo verified!" : "Pat received."
    case (.pauli, .boop):
      "sensor ping!"
    case (.pauli, .scratch(.earOrTemple)):
      "sensor happy!"
    case (.pauli, .scratch(.chin)):
      "servo hum…"
    case (.pauli, .swipe(_, let intensity)):
      safeUnit(intensity) >= 0.75 ? "Velocity spike!" : "Servo follow."

    case (.dog, .pat(let comboCount)):
      comboCount >= 5 ? "Yes—keep going!" : "More pats?"
    case (.dog, .boop):
      "boop!"
    case (.dog, .scratch(.earOrTemple)):
      "yes, there!"
    case (.dog, .scratch(.chin)):
      "more, please!"
    case (.dog, .swipe(_, let intensity)):
      safeUnit(intensity) >= 0.75 ? "Wheee!" : "Nice ruffle!"
    }
  }

  private static func safeUnit(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }

  private enum ResponseMode: Equatable {
    case neutral
    case drowsy
    case stormComfort
    case familiar
  }
}
