import Testing
@testable import DeskPetCore

@Suite("Pet autonomy")
struct PetAutonomyTests {
    @Test("circadian rhythm makes midday more energetic than midnight")
    func circadianEnergy() {
        let midday = PetAutonomyDirector.state(
            pet: .cat,
            hourOfDay: 13,
            secondsSinceInteraction: 120,
            workProgress: 0.2,
            mood: .sunny,
            bondProgress: 0.4
        )
        let midnight = PetAutonomyDirector.state(
            pet: .cat,
            hourOfDay: 0,
            secondsSinceInteraction: 120,
            workProgress: 0.2,
            mood: .sunny,
            bondProgress: 0.4
        )

        #expect(midday.energy > midnight.energy)
        #expect(midnight.dominantDrive == .rest)
    }

    @Test("social need grows after a quiet spell and differs by personality")
    func socialNeedGrows() {
        let recent = PetAutonomyDirector.state(
            pet: .dog,
            hourOfDay: 14,
            secondsSinceInteraction: 10,
            workProgress: 0.1,
            mood: .cozy,
            bondProgress: 0.8
        )
        let waitingDog = PetAutonomyDirector.state(
            pet: .dog,
            hourOfDay: 14,
            secondsSinceInteraction: 18 * 60,
            workProgress: 0.1,
            mood: .cozy,
            bondProgress: 0.8
        )
        let waitingCat = PetAutonomyDirector.state(
            pet: .cat,
            hourOfDay: 14,
            secondsSinceInteraction: 18 * 60,
            workProgress: 0.1,
            mood: .cozy,
            bondProgress: 0.8
        )

        #expect(waitingDog.socialNeed > recent.socialNeed)
        #expect(waitingDog.socialNeed > waitingCat.socialNeed)
        #expect(waitingDog.dominantDrive == .seekAttention)
    }

    @Test("long focus sessions trigger a companion stretch")
    func focusCompanion() {
        let state = PetAutonomyDirector.state(
            pet: .pauli,
            hourOfDay: 15,
            secondsSinceInteraction: 90,
            workProgress: 0.92,
            mood: .cloudy,
            bondProgress: 0.5
        )

        #expect(state.dominantDrive == .encourageBreak)
        #expect(
            PetAutonomyDirector.event(for: .pauli, state: state, roll: 0)
                == .stretch
        )
    }

    @Test("weather watching produces character-specific behavior")
    func weatherWatching() {
        let state = PetAutonomyDirector.state(
            pet: .cat,
            hourOfDay: 12,
            secondsSinceInteraction: 60,
            workProgress: 0.2,
            mood: .stormy,
            bondProgress: 0.2
        )

        #expect(state.weatherInterest > 0.8)
        #expect(state.dominantDrive == .observeWeather)
        #expect(
            PetAutonomyDirector.event(for: .cat, state: state, roll: 0)
                == .lookAround
        )
    }

    @Test("active drives shorten idle waits without becoming distracting")
    func contextualIdleDuration() {
        let restful = PetAutonomyState(
            energy: 0.2,
            curiosity: 0.2,
            socialNeed: 0.1,
            focusPressure: 0.1,
            weatherInterest: 0.2,
            dominantDrive: .rest
        )
        let curious = PetAutonomyState(
            energy: 0.9,
            curiosity: 0.9,
            socialNeed: 0.5,
            focusPressure: 0.2,
            weatherInterest: 0.5,
            dominantDrive: .explore
        )

        let restfulDelay = PetAutonomyDirector.idleDuration(
            base: 16,
            state: restful
        )
        let curiousDelay = PetAutonomyDirector.idleDuration(
            base: 16,
            state: curious
        )

        #expect((8...30).contains(restfulDelay))
        #expect((8...30).contains(curiousDelay))
        #expect(curiousDelay < restfulDelay)
    }

    @Test("invalid inputs remain finite and bounded")
    func invalidInputsAreSafe() {
        let state = PetAutonomyDirector.state(
            pet: .dog,
            hourOfDay: -500,
            secondsSinceInteraction: .infinity,
            workProgress: .nan,
            mood: .rainy,
            bondProgress: -.infinity
        )

        for value in [
            state.energy,
            state.curiosity,
            state.socialNeed,
            state.focusPressure,
            state.weatherInterest,
        ] {
            #expect(value.isFinite)
            #expect((0...1).contains(value))
        }
    }

    @Test("motion scheduling consumes the current autonomous drive")
    func motionSchedulingUsesAutonomy() {
        let state = PetAutonomyState(
            energy: 0.8,
            curiosity: 0.4,
            socialNeed: 0.3,
            focusPressure: 0.95,
            weatherInterest: 0.4,
            dominantDrive: .encourageBreak
        )
        let base = PetMotionDirector.cadence(for: .dog, seed: 77)
        let contextualDelay = PetAutonomyDirector.idleDuration(
            base: base.idleDuration,
            state: state
        )

        let before = PetMotionDirector.frame(
            pet: .dog,
            time: contextualDelay - 0.01,
            seed: 77,
            isEligible: true,
            reduceMotion: false,
            autonomyState: state
        )
        let active = PetMotionDirector.frame(
            pet: .dog,
            time: contextualDelay + 0.1,
            seed: 77,
            isEligible: true,
            reduceMotion: false,
            autonomyState: state
        )

        #expect(before == .idle)
        #expect(active.event == .stretch || active.event == .perkUp)
    }

    @Test("familiar rhythm makes attention seeking happen sooner")
    func memoryShapesSocialNeed() {
        let unfamiliar = PetAutonomyDirector.state(
            pet: .cat,
            hourOfDay: 14,
            secondsSinceInteraction: 12 * 60,
            workProgress: 0.1,
            mood: .cozy,
            bondProgress: 0.4,
            familiarity: 0,
            preferredInteraction: nil,
            rhythmAffinity: 0
        )
        let familiar = PetAutonomyDirector.state(
            pet: .cat,
            hourOfDay: 14,
            secondsSinceInteraction: 12 * 60,
            workProgress: 0.1,
            mood: .cozy,
            bondProgress: 0.4,
            familiarity: 0.9,
            preferredInteraction: .scratch,
            rhythmAffinity: 1
        )

        #expect(familiar.socialNeed > unfamiliar.socialNeed + 0.15)
        #expect(familiar.preferredInteraction == .scratch)
        #expect(familiar.familiarity == 0.9)
        #expect(familiar.rhythmAffinity == 1)
    }

    @Test("attention gestures reflect the remembered preference")
    func preferredInteractionShapesMotion() {
        let dancing = PetAutonomyState(
            energy: 0.8,
            curiosity: 0.5,
            socialNeed: 0.9,
            focusPressure: 0,
            weatherInterest: 0.2,
            dominantDrive: .seekAttention,
            preferredInteraction: .dance
        )
        let playing = PetAutonomyState(
            energy: 0.8,
            curiosity: 0.5,
            socialNeed: 0.9,
            focusPressure: 0,
            weatherInterest: 0.2,
            dominantDrive: .seekAttention,
            preferredInteraction: .toy
        )

        #expect(PetAutonomyDirector.event(
            for: .dog,
            state: dancing,
            roll: 0
        ) == .idleAction2)
        #expect(PetAutonomyDirector.event(
            for: .dog,
            state: playing,
            roll: 0
        ) == .walk)
    }
}
