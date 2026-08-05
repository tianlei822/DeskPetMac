import Testing
@testable import DeskPetCore

@Suite("Pet sound design")
struct PetSoundDesignTests {
    @Test("interaction sounds are opt-in by default")
    func soundsDefaultToOff() {
        #expect(!PetSoundPreference.defaultEnabled)
    }

    @Test("every cue stays short, quiet, and inside a comfortable range")
    func profilesStayRestrained() {
        for petKind in PetKind.allCases {
            for cue in PetSoundCue.allCases {
                let profile = PetSoundDesign.profile(
                    for: petKind,
                    cue: cue
                )
                #expect((120...1_600).contains(profile.startFrequency))
                #expect((120...1_600).contains(profile.endFrequency))
                #expect((0.04...0.22).contains(profile.duration))
                #expect((0.02...0.16).contains(profile.amplitude))
                #expect((0...0.5).contains(profile.harmonicMix))
            }
        }
    }

    @Test("the same cue keeps a distinct voice for each companion")
    func companionsSoundDistinct() {
        let profiles = PetKind.allCases.map {
            PetSoundDesign.profile(for: $0, cue: .boop)
        }

        #expect(Set(profiles.map(\.startFrequency)).count == 3)
        #expect(Set(profiles.map(\.endFrequency)).count == 3)
    }

    @Test("satisfying moments are warmer and longer than a boop")
    func rewardCueFeelsMoreSettled() {
        for petKind in PetKind.allCases {
            let boop = PetSoundDesign.profile(for: petKind, cue: .boop)
            let satisfied = PetSoundDesign.profile(
                for: petKind,
                cue: .treatSatisfied
            )

            #expect(satisfied.duration > boop.duration)
            #expect(satisfied.endFrequency <= boop.endFrequency)
        }
    }
}
