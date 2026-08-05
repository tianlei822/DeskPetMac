public enum PetActivityKind: String, CaseIterable, Equatable, Sendable {
  case autonomous
  case sleeping
  case waking
  case personality
  case reminder
  case roaming
  case feeding
  case dancing
  case scratching
  case nuzzling
}

public struct PetActivity: Equatable, Sendable {
  public let kind: PetActivityKind
  public let priority: Int
  public let isInterruptible: Bool
  public let autonomyDrive: PetAutonomyDrive?
  public let personalityPose: PersonalityPose?
  public let relationshipGesture: PetRelationshipGesture?

  public static func autonomous(_ drive: PetAutonomyDrive) -> PetActivity {
    PetActivity(
      kind: .autonomous,
      priority: 10,
      isInterruptible: true,
      autonomyDrive: drive,
      personalityPose: nil,
      relationshipGesture: nil
    )
  }

  public static let sleeping = PetActivity(
    kind: .sleeping,
    priority: 20,
    isInterruptible: true,
    autonomyDrive: .rest,
    personalityPose: nil,
    relationshipGesture: nil
  )

  public static func waking(_ pose: PersonalityPose) -> PetActivity {
    PetActivity(
      kind: .waking,
      priority: 25,
      isInterruptible: true,
      autonomyDrive: nil,
      personalityPose: pose,
      relationshipGesture: nil
    )
  }

  public static func personality(
    _ pose: PersonalityPose,
    relationshipGesture: PetRelationshipGesture? = nil
  ) -> PetActivity {
    PetActivity(
      kind: .personality,
      priority: 30,
      isInterruptible: true,
      autonomyDrive: nil,
      personalityPose: pose,
      relationshipGesture: relationshipGesture
    )
  }

  public static let reminder = PetActivity(
    kind: .reminder,
    priority: 55,
    isInterruptible: true,
    autonomyDrive: .encourageBreak,
    personalityPose: .stretch,
    relationshipGesture: nil
  )

  public static let roaming = PetActivity(
    kind: .roaming,
    priority: 50,
    isInterruptible: true,
    autonomyDrive: .explore,
    personalityPose: nil,
    relationshipGesture: nil
  )

  public static func feeding(_ phase: PetTreatPhase) -> PetActivity {
    let pose: PersonalityPose? =
      switch phase {
      case .tossing, .watching:
        .perk
      case .approaching, .sniffing:
        .peek
      case .eating, .satisfied:
        .proud
      case .completed:
        nil
      }
    return PetActivity(
      kind: .feeding,
      priority: 58,
      isInterruptible: true,
      autonomyDrive: nil,
      personalityPose: pose,
      relationshipGesture: nil
    )
  }

  public static let dancing = PetActivity(
    kind: .dancing,
    priority: 60,
    isInterruptible: false,
    autonomyDrive: nil,
    personalityPose: nil,
    relationshipGesture: nil
  )

  public static let scratching = PetActivity(
    kind: .scratching,
    priority: 65,
    isInterruptible: false,
    autonomyDrive: nil,
    personalityPose: nil,
    relationshipGesture: nil
  )

  public static let nuzzling = PetActivity(
    kind: .nuzzling,
    priority: 70,
    isInterruptible: false,
    autonomyDrive: nil,
    personalityPose: nil,
    relationshipGesture: nil
  )
}

public struct PetActivityContext: Equatable, Sendable {
  public let isSleeping: Bool
  public let wakePose: PersonalityPose?
  public let isDancing: Bool
  public let isScratching: Bool
  public let isNuzzling: Bool
  public let isReminderVisible: Bool
  public let isRoaming: Bool
  public let feedingPhase: PetTreatPhase?
  public let personalityPose: PersonalityPose?
  public let relationshipGesture: PetRelationshipGesture?
  public let autonomyDrive: PetAutonomyDrive

  public init(
    isSleeping: Bool = false,
    wakePose: PersonalityPose? = nil,
    isDancing: Bool = false,
    isScratching: Bool = false,
    isNuzzling: Bool = false,
    isReminderVisible: Bool = false,
    isRoaming: Bool = false,
    feedingPhase: PetTreatPhase? = nil,
    personalityPose: PersonalityPose? = nil,
    relationshipGesture: PetRelationshipGesture? = nil,
    autonomyDrive: PetAutonomyDrive
  ) {
    self.isSleeping = isSleeping
    self.wakePose = wakePose
    self.isDancing = isDancing
    self.isScratching = isScratching
    self.isNuzzling = isNuzzling
    self.isReminderVisible = isReminderVisible
    self.isRoaming = isRoaming
    self.feedingPhase = feedingPhase
    self.personalityPose = personalityPose
    self.relationshipGesture = relationshipGesture
    self.autonomyDrive = autonomyDrive
  }
}

public enum PetActivityGraph {
  public static func resolve(_ context: PetActivityContext) -> PetActivity {
    if context.isNuzzling {
      return .nuzzling
    }
    if context.isScratching {
      return .scratching
    }
    if context.isDancing {
      return .dancing
    }
    if let feedingPhase = context.feedingPhase {
      return .feeding(feedingPhase)
    }
    if context.isReminderVisible {
      return .reminder
    }
    if let personalityPose = context.personalityPose {
      return .personality(
        personalityPose,
        relationshipGesture: context.relationshipGesture
      )
    }
    if let wakePose = context.wakePose {
      return .waking(wakePose)
    }
    if context.isSleeping {
      return .sleeping
    }
    if context.isRoaming {
      return .roaming
    }
    return .autonomous(context.autonomyDrive)
  }

  public static func canInterrupt(
    _ current: PetActivity,
    with candidate: PetActivity
  ) -> Bool {
    candidate.kind != current.kind && candidate.priority > current.priority
  }
}
