import Foundation
import Testing
@testable import DeskPetCore

@Suite("Pet attention response")
struct PetAttentionResponseTests {
  @Test("eyes and ears lead the head and body")
  func eyesAndEarsLead() {
    let eyeLead = PetAttentionTimeline.phase(
      for: .cat,
      elapsed: 0.04,
      reduceMotion: false
    )
    let earLead = PetAttentionTimeline.phase(
      for: .cat,
      elapsed: 0.13,
      reduceMotion: false
    )
    let headFollow = PetAttentionTimeline.phase(
      for: .cat,
      elapsed: 0.25,
      reduceMotion: false
    )
    let bodyFollow = PetAttentionTimeline.phase(
      for: .cat,
      elapsed: 0.48,
      reduceMotion: false
    )

    #expect(eyeLead.eyeProgress > 0)
    #expect(eyeLead.earProgress == 0)
    #expect(eyeLead.headProgress == 0)
    #expect(eyeLead.bodyProgress == 0)

    #expect(earLead.eyeProgress == 1)
    #expect(earLead.earProgress > 0)
    #expect(earLead.headProgress == 0)
    #expect(earLead.bodyProgress == 0)

    #expect(headFollow.eyeProgress == 1)
    #expect(headFollow.earProgress > headFollow.headProgress)
    #expect(headFollow.headProgress > 0)
    #expect(headFollow.bodyProgress == 0)
    #expect(headFollow.usesCuriousArtwork)

    #expect(bodyFollow.headProgress > bodyFollow.bodyProgress)
    #expect(bodyFollow.bodyProgress > 0)
  }

  @Test("companions keep distinct attention tempos")
  func characterTemposDiffer() {
    let elapsed = 0.18
    let cat = PetAttentionTimeline.phase(
      for: .cat,
      elapsed: elapsed,
      reduceMotion: false
    )
    let pauli = PetAttentionTimeline.phase(
      for: .pauli,
      elapsed: elapsed,
      reduceMotion: false
    )
    let dog = PetAttentionTimeline.phase(
      for: .dog,
      elapsed: elapsed,
      reduceMotion: false
    )

    #expect(dog.headProgress > cat.headProgress)
    #expect(cat.headProgress >= pauli.headProgress)
    #expect(pauli.earProgress < cat.earProgress)
  }

  @Test("reduced motion settles without animated staging")
  func reducedMotionSettlesImmediately() {
    for pet in PetKind.allCases {
      let phase = PetAttentionTimeline.phase(
        for: pet,
        elapsed: 0,
        reduceMotion: true
      )

      #expect(phase.eyeProgress == 1)
      #expect(phase.earProgress == 1)
      #expect(phase.headProgress == 1)
      #expect(phase.bodyProgress == 1)
      #expect(phase.usesCuriousArtwork)
    }
  }

  @Test("invalid elapsed time remains neutral")
  func invalidElapsedIsNeutral() {
    for elapsed in [Double.nan, .infinity, -.infinity, -1] {
      #expect(
        PetAttentionTimeline.phase(
          for: .dog,
          elapsed: elapsed,
          reduceMotion: false
        ) == .neutral
      )
    }
  }

  @Test("cursor attention restarts after leaving the radius")
  func cursorAttentionRestarts() {
    var tracker = PetAttentionTracker()

    tracker.observe(
      offset: CGSize(width: 0.8, height: -0.2),
      at: 10
    )
    #expect(abs((tracker.sample(at: 10.2)?.elapsed ?? 0) - 0.2) < 0.000_001)
    #expect(tracker.sample(at: 10.2)?.offset.width == 0.8)

    tracker.observe(offset: nil, at: 10.3)
    #expect(tracker.sample(at: 10.4) == nil)

    tracker.observe(
      offset: CGSize(width: -0.4, height: 0.3),
      at: 20
    )
    let restarted = tracker.sample(at: 20.04)
    #expect(abs((restarted?.elapsed ?? 0) - 0.04) < 0.000_001)
    #expect(restarted?.offset.width == -0.4)
  }

  @Test("cursor attention sanitizes unsafe samples")
  func cursorAttentionSanitizesUnsafeSamples() {
    var tracker = PetAttentionTracker()

    tracker.observe(
      offset: CGSize(width: CGFloat.nan, height: 0),
      at: 1
    )
    #expect(tracker.sample(at: 1.2) == nil)

    tracker.observe(
      offset: CGSize(width: 2, height: -3),
      at: 2
    )
    #expect(tracker.sample(at: 2.1)?.offset == CGSize(width: 1, height: -1))
    #expect(tracker.sample(at: .nan) == nil)
  }
}
