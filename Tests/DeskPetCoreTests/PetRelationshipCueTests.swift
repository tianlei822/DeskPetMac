import Testing
@testable import DeskPetCore

@Suite("Pet relationship cues")
struct PetRelationshipCueTests {
    @Test("unfamiliar or blocked pets remain quiet")
    func quietUntilRelationshipIsEstablished() {
        let unfamiliar = PetRelationshipCuePlanner.cue(
            for: PetRelationshipCueContext(
                petKind: .cat,
                preferredInteraction: .scratch,
                familiarity: 0.08,
                rhythmAffinity: 0.8,
                autonomyDrive: .seekAttention,
                isPresentationBlocked: false
            )
        )
        let blocked = PetRelationshipCuePlanner.cue(
            for: PetRelationshipCueContext(
                petKind: .dog,
                preferredInteraction: .toy,
                familiarity: 0.9,
                rhythmAffinity: 0.9,
                autonomyDrive: .seekAttention,
                isPresentationBlocked: true
            )
        )

        #expect(unfamiliar == nil)
        #expect(blocked == nil)
    }

    @Test("habitual hours unlock a remembered preference cue")
    func cueUsesPreferenceAndRhythm() {
        let cue = PetRelationshipCuePlanner.cue(
            for: PetRelationshipCueContext(
                petKind: .cat,
                preferredInteraction: .scratch,
                familiarity: 0.35,
                rhythmAffinity: 0.7,
                autonomyDrive: .seekAttention,
                isPresentationBlocked: false
            )
        )

        #expect(cue?.id == "relationship.cat.scratch")
        #expect(cue?.line.lowercased().contains("ear") == true)
        #expect(cue?.pose == .perk)
        #expect(cue?.gesture == .inviteTouch)
    }

    @Test("deep familiarity works outside a learned hour")
    func deepFamiliarityCanInitiate() {
        let cue = PetRelationshipCuePlanner.cue(
            for: PetRelationshipCueContext(
                petKind: .pauli,
                preferredInteraction: .dance,
                familiarity: 0.75,
                rhythmAffinity: 0,
                autonomyDrive: .seekAttention,
                isPresentationBlocked: false
            )
        )

        #expect(cue != nil)
        #expect(cue?.pose == .proud)
        #expect(cue?.gesture == .sharedSway)
    }

    @Test("each companion asks in its own voice")
    func companionVoicesRemainDistinct() {
        let lines = PetKind.allCases.compactMap { petKind in
            PetRelationshipCuePlanner.cue(
                for: PetRelationshipCueContext(
                    petKind: petKind,
                    preferredInteraction: .toy,
                    familiarity: 0.8,
                    rhythmAffinity: 0.8,
                    autonomyDrive: .seekAttention,
                    isPresentationBlocked: false
                )
            )?.line
        }

        #expect(lines.count == 3)
        #expect(Set(lines).count == 3)
        #expect(lines.allSatisfy { !$0.lowercased().contains("missed") })
    }

    @Test("remembered preferences choose a meaningful relationship gesture")
    func preferencesChooseRelationshipGestures() {
        let expected: [PetInteractionPreference: PetRelationshipGesture] = [
            .pat: .inviteTouch,
            .boop: .inviteTouch,
            .scratch: .inviteTouch,
            .swipe: .inviteTouch,
            .nuzzle: .leanClose,
            .dance: .sharedSway,
            .treat: .anticipatePlay,
            .toy: .anticipatePlay,
        ]

        for preference in PetInteractionPreference.allCases {
            let cue = PetRelationshipCuePlanner.cue(
                for: PetRelationshipCueContext(
                    petKind: .dog,
                    preferredInteraction: preference,
                    familiarity: 0.8,
                    rhythmAffinity: 0.8,
                    autonomyDrive: .seekAttention,
                    isPresentationBlocked: false
                )
            )
            #expect(cue?.gesture == expected[preference])
        }
    }

    @Test("relationship gestures enter hold and settle without snapping")
    func gesturesHaveCompleteMotionEnvelopes() {
        for gesture in PetRelationshipGesture.allCases {
            let start = PetRelationshipGestureMotion.pose(
                for: .cat,
                gesture: gesture,
                elapsed: 0,
                reduceMotion: false
            )
            let middle = PetRelationshipGestureMotion.pose(
                for: .cat,
                gesture: gesture,
                elapsed: 1.4,
                reduceMotion: false
            )
            let end = PetRelationshipGestureMotion.pose(
                for: .cat,
                gesture: gesture,
                elapsed: 3.5,
                reduceMotion: false
            )

            #expect(start == .neutral)
            #expect(middle != .neutral)
            #expect(end == .neutral)
        }
    }

    @Test("companions express the same relationship gesture differently")
    func companionsKeepDistinctBodyLanguage() {
        let poses = PetKind.allCases.map { pet in
            PetRelationshipGestureMotion.pose(
                for: pet,
                gesture: .inviteTouch,
                elapsed: 1.1,
                reduceMotion: false
            )
        }

        #expect(poses.count == 3)
        #expect(poses[0] != poses[1])
        #expect(poses[1] != poses[2])
        #expect(poses[0] != poses[2])
    }

    @Test("relationship gestures keep readable motion silhouettes")
    func gesturesKeepReadableSilhouettes() {
        let invite = PetRelationshipGestureMotion.pose(
            for: .cat,
            gesture: .inviteTouch,
            elapsed: 1.2,
            reduceMotion: false
        )
        let close = PetRelationshipGestureMotion.pose(
            for: .cat,
            gesture: .leanClose,
            elapsed: 1.2,
            reduceMotion: false
        )
        let sway = PetRelationshipGestureMotion.pose(
            for: .cat,
            gesture: .sharedSway,
            elapsed: 1.2,
            reduceMotion: false
        )
        let play = PetRelationshipGestureMotion.pose(
            for: .cat,
            gesture: .anticipatePlay,
            elapsed: 1.2,
            reduceMotion: false
        )

        #expect(abs(invite.x) > abs(invite.y) * 2)
        #expect(close.scale > 1.015)
        #expect(close.y < -1.5)
        #expect(abs(sway.tiltDegrees) > abs(sway.x))
        #expect(play.y < -2.5)
        #expect(play.scale > 1.018)
    }

    @Test("relationship motion respects Reduce Motion and unsafe time")
    func relationshipMotionRespectsSafety() {
        #expect(
            PetRelationshipGestureMotion.pose(
                for: .dog,
                gesture: .sharedSway,
                elapsed: 1,
                reduceMotion: true
            ) == .neutral
        )
        for elapsed in [Double.nan, .infinity, -.infinity, -1] {
            #expect(
                PetRelationshipGestureMotion.pose(
                    for: .pauli,
                    gesture: .leanClose,
                    elapsed: elapsed,
                    reduceMotion: false
                ) == .neutral
            )
        }
    }

    @Test("relationship gesture travels through the activity graph")
    func relationshipGestureTravelsThroughActivity() {
        let activity = PetActivityGraph.resolve(
            PetActivityContext(
                personalityPose: .perk,
                relationshipGesture: .inviteTouch,
                autonomyDrive: .seekAttention
            )
        )

        #expect(activity.kind == .personality)
        #expect(activity.personalityPose == .perk)
        #expect(activity.relationshipGesture == .inviteTouch)
    }
}
