import Testing

@testable import DeskPetCore

@Suite("Pet contextual touch response")
struct PetTouchResponseTests {
  @Test("scratch position changes the response for every companion")
  func scratchPositionChangesLine() {
    for petKind in PetKind.allCases {
      let ear = response(
        petKind: petKind,
        action: .scratch(.earOrTemple)
      )
      let chin = response(
        petKind: petKind,
        action: .scratch(.chin)
      )

      #expect(ear.line != chin.line)
      #expect(ear.presentsCallout)
      #expect(chin.presentsCallout)
    }
  }

  @Test("swipe speed controls reaction strength and familiar celebration")
  func swipeSpeedChangesStrength() {
    let low = response(
      petKind: .dog,
      action: .swipe(direction: .right, intensity: 0.25),
      bondLevel: .companion,
      familiarity: 0.8
    )
    let high = response(
      petKind: .dog,
      action: .swipe(direction: .right, intensity: 0.95),
      bondLevel: .companion,
      familiarity: 0.8
    )

    #expect(low.intensity == .subtle)
    #expect(high.intensity == .delighted)
    #expect(!low.addsHeart)
    #expect(high.addsHeart)
    #expect(low.line != high.line)
  }

  @Test("touching a sleeping companion gets a distinct drowsy voice")
  func interruptedSleepChangesVoice() {
    let lines = PetKind.allCases.map { petKind in
      response(
        petKind: petKind,
        action: .boop,
        interruptedActivity: .sleeping
      ).line
    }

    #expect(Set(lines).count == PetKind.allCases.count)
    for (petKind, line) in zip(PetKind.allCases, lines) {
      #expect(
        line
          != response(
            petKind: petKind,
            action: .boop
          ).line
      )
    }
  }

  @Test("stormy mood changes an otherwise identical touch")
  func stormyMoodChangesResponse() {
    for petKind in PetKind.allCases {
      let cozy = response(
        petKind: petKind,
        action: .pat(comboCount: 1),
        mood: .cozy
      )
      let stormy = response(
        petKind: petKind,
        action: .pat(comboCount: 1),
        mood: .stormy
      )

      #expect(stormy.line != cozy.line)
      #expect(!cozy.presentsCallout)
      #expect(stormy.presentsCallout)
    }
  }

  @Test("a familiar bond earns a remembered-touch response")
  func familiarBondChangesResponse() {
    for petKind in PetKind.allCases {
      let newFriend = response(
        petKind: petKind,
        action: .scratch(.earOrTemple)
      )
      let companion = response(
        petKind: petKind,
        action: .scratch(.earOrTemple),
        bondLevel: .companion,
        familiarity: 0.7
      )

      #expect(companion.line != newFriend.line)
      #expect(companion.intensity.rawValue >= newFriend.intensity.rawValue)
    }
  }

  @Test("only a meaningful pat context opens a callout")
  func patCalloutStaysRestrained() {
    let ordinary = response(
      petKind: .cat,
      action: .pat(comboCount: 1)
    )
    let combo = response(
      petKind: .cat,
      action: .pat(comboCount: 5)
    )

    #expect(!ordinary.presentsCallout)
    #expect(combo.presentsCallout)
    #expect(combo.intensity == .delighted)
  }

  private func response(
    petKind: PetKind,
    action: PetTouchAction,
    mood: PetWeatherMood = .cozy,
    bondLevel: BondLevel = .newFriend,
    familiarity: Double = 0,
    interruptedActivity: PetActivityKind = .autonomous
  ) -> PetTouchResponse {
    PetTouchResponsePlanner.response(
      for: PetTouchResponseContext(
        petKind: petKind,
        action: action,
        mood: mood,
        bondLevel: bondLevel,
        familiarity: familiarity,
        interruptedActivity: interruptedActivity
      )
    )
  }
}
