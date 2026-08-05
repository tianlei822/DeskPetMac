import Testing

@testable import DeskPetCore

@Suite("Pet greeting rituals")
struct PetGreetingRitualTests {
  @Test("brief returns stay as quiet callouts")
  func briefReturnsStayQuiet() {
    for petKind in PetKind.allCases {
      let ritual = PetGreetingRitualPlanner.ritual(
        for:
          PetGreetingRitualContext(
            greeting: .returningSoon,
            petKind: petKind,
            displayName: petKind.displayName,
            familiarity: 0.8
          ))

      #expect(ritual.presentation == .callout)
      #expect(ritual.pose == nil)
      #expect(!ritual.playsAffectionPulse)
      #expect(ritual.heartPulseDelays.isEmpty)
      #expect(ritual.duration <= 1.2)
    }
  }

  @Test("a normal welcome uses a warm pose and one restrained pulse")
  func normalWelcomeUsesBehavior() {
    for petKind in PetKind.allCases {
      let ritual = PetGreetingRitualPlanner.ritual(
        for:
          PetGreetingRitualContext(
            greeting: .welcomeBack,
            petKind: petKind,
            displayName: petKind.displayName,
            familiarity: 0.45
          ))

      #expect(ritual.presentation == .personalityMoment)
      #expect(ritual.pose != nil)
      #expect(ritual.playsAffectionPulse)
      #expect(ritual.heartPulseDelays.count == 1)
      #expect((2.5...3.5).contains(ritual.duration))
    }
  }

  @Test("a familiar long absence earns a longer two-stage reunion")
  func familiarLongAbsenceIsWarmer() {
    for petKind in PetKind.allCases {
      let welcome = PetGreetingRitualPlanner.ritual(
        for:
          PetGreetingRitualContext(
            greeting: .welcomeBack,
            petKind: petKind,
            displayName: petKind.displayName,
            familiarity: 0.8
          ))
      let reunion = PetGreetingRitualPlanner.ritual(
        for:
          PetGreetingRitualContext(
            greeting: .longTimeNoSee,
            petKind: petKind,
            displayName: petKind.displayName,
            familiarity: 0.8
          ))

      #expect(reunion.presentation == .personalityMoment)
      #expect(reunion.duration > welcome.duration)
      #expect(reunion.heartPulseDelays.count == 2)
      #expect(reunion.heartPulseDelays == reunion.heartPulseDelays.sorted())
      #expect(reunion.playsAffectionPulse)
    }
  }

  @Test("first meetings introduce the learned name without false intimacy")
  func firstMeetingUsesNameWithoutHearts() {
    let ritual = PetGreetingRitualPlanner.ritual(
      for:
        PetGreetingRitualContext(
          greeting: .firstMeeting,
          petKind: .pauli,
          displayName: "Orbit",
          familiarity: 0
        ))

    #expect(ritual.presentation == .personalityMoment)
    #expect(ritual.line.contains("Orbit"))
    #expect(ritual.pose == .perk)
    #expect(!ritual.playsAffectionPulse)
    #expect(ritual.heartPulseDelays.isEmpty)
  }

  @Test("each companion keeps a distinct reunion voice")
  func reunionVoicesRemainDistinct() {
    let lines = PetKind.allCases.map { petKind in
      PetGreetingRitualPlanner.ritual(
        for:
          PetGreetingRitualContext(
            greeting: .longTimeNoSee,
            petKind: petKind,
            displayName: petKind.displayName,
            familiarity: 0.8
          )
      ).line
    }

    #expect(Set(lines).count == PetKind.allCases.count)
  }
}
