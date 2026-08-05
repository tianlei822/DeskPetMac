import CoreGraphics
import DeskPetCore
import Testing

@testable import DeskPetMac

@Suite("Pet unified rig")
struct PetUnifiedRigTests {
  @Test("the complete locomotion chain uses canonical artwork")
  func locomotionUsesCanonicalArtwork() {
    let walk = PetMotionDirector.previewFrame(
      pet: .cat,
      event: .walk,
      time: 0.4,
      reduceMotion: false
    )
    #expect(
      PetUnifiedRigPolicy.usesCanonicalArtwork(
        motion: walk,
        rootMotion: nil,
        reduceMotion: false
      ))

    let plan = PetRootMotionPlan.resolve(
      startX: 500,
      visibleMinX: 0,
      visibleMaxX: 1440,
      windowWidth: 260,
      desiredDistance: 120,
      preferredDirection: .right
    )
    let samples = [
      0,
      plan.preparationDuration * 0.5,
      plan.preparationDuration * 0.85,
      plan.preparationDuration + plan.movementDuration * 0.4,
      plan.preparationDuration + plan.movementDuration * 0.9,
      plan.preparationDuration + plan.movementDuration
        + plan.settlingDuration * 0.5,
      plan.duration,
    ]
    for elapsed in samples {
      let rootMotion = plan.frame(at: elapsed)
      let motion = PetMotionDirector.rootMotionFrame(
        pet: .cat,
        rootMotion: rootMotion,
        reduceMotion: false
      )
      #expect(
        PetUnifiedRigPolicy.usesCanonicalArtwork(
          motion: motion,
          rootMotion: rootMotion,
          reduceMotion: false
        ))
    }

    let stretch = PetMotionDirector.previewFrame(
      pet: .cat,
      event: .stretch,
      time: 0.8,
      reduceMotion: false
    )
    #expect(
      !PetUnifiedRigPolicy.usesCanonicalArtwork(
        motion: stretch,
        rootMotion: nil,
        reduceMotion: false
      ))
    #expect(
      !PetUnifiedRigPolicy.usesCanonicalArtwork(
        motion: walk,
        rootMotion: nil,
        reduceMotion: true
      ))
  }

  @Test("idle gestures use canonical artwork while stretch stays explicit")
  func idleGesturesUseCanonicalArtwork() {
    for pet in PetKind.allCases {
      for event in [
        PetMotionEvent.idleAction1,
        .idleAction2,
        .lookAround,
        .perkUp,
      ] {
        let motion = PetMotionDirector.previewFrame(
          pet: pet,
          event: event,
          time: PetMotionDirector.eventDuration(for: event, pet: pet) * 0.5,
          reduceMotion: false
        )
        #expect(
          PetUnifiedRigPolicy.usesCanonicalArtwork(
            motion: motion,
            rootMotion: nil,
            reduceMotion: false
          ))
      }

      let stretch = PetMotionDirector.previewFrame(
        pet: pet,
        event: .stretch,
        time: 1.1,
        reduceMotion: false
      )
      #expect(
        !PetUnifiedRigPolicy.usesCanonicalArtwork(
          motion: stretch,
          rootMotion: nil,
          reduceMotion: false
        ))
    }
  }

  @Test("direct touch uses canonical artwork outside Reduce Motion")
  func directTouchUsesCanonicalArtwork() {
    #expect(
      PetUnifiedRigPolicy.usesCanonicalDirectTouchArtwork(
        isActive: true,
        reduceMotion: false
      ))
    #expect(
      !PetUnifiedRigPolicy.usesCanonicalDirectTouchArtwork(
        isActive: false,
        reduceMotion: false
      ))
    #expect(
      !PetUnifiedRigPolicy.usesCanonicalDirectTouchArtwork(
        isActive: true,
        reduceMotion: true
      ))
  }

  @Test("relationship gestures use canonical artwork outside Reduce Motion")
  func relationshipGesturesUseCanonicalArtwork() {
    #expect(
      PetUnifiedRigPolicy.usesCanonicalRelationshipArtwork(
        personalityPose: .perk,
        relationshipGesture: .inviteTouch,
        reduceMotion: false
      ))
    #expect(
      !PetUnifiedRigPolicy.usesCanonicalRelationshipArtwork(
        personalityPose: .perk,
        relationshipGesture: nil,
        reduceMotion: false
      ))
    #expect(
      !PetUnifiedRigPolicy.usesCanonicalRelationshipArtwork(
        personalityPose: nil,
        relationshipGesture: .inviteTouch,
        reduceMotion: false
      ))
    #expect(
      !PetUnifiedRigPolicy.usesCanonicalRelationshipArtwork(
        personalityPose: .perk,
        relationshipGesture: .inviteTouch,
        reduceMotion: true
      ))
  }

  @Test("relationship joints enter and settle without snapping")
  func relationshipJointsHaveCompleteEnvelopes() {
    for pet in PetKind.allCases {
      for gesture in PetRelationshipGesture.allCases {
        let start = PetUnifiedRigRelationshipMotion.pose(
          pet: pet,
          gesture: gesture,
          elapsed: 0,
          reduceMotion: false
        )
        let hold = PetUnifiedRigRelationshipMotion.pose(
          pet: pet,
          gesture: gesture,
          elapsed: 1.2,
          reduceMotion: false
        )
        let completed = PetUnifiedRigRelationshipMotion.pose(
          pet: pet,
          gesture: gesture,
          elapsed: PetRelationshipGestureMotion.duration,
          reduceMotion: false
        )

        #expect(start == .neutral)
        #expect(hold != .neutral)
        #expect(completed == .neutral)
      }
    }
  }

  @Test("relationship joints preserve four readable intentions")
  func relationshipJointsPreserveIntentions() {
    for pet in PetKind.allCases {
      let invite = PetUnifiedRigRelationshipMotion.pose(
        pet: pet,
        gesture: .inviteTouch,
        elapsed: 1.2,
        reduceMotion: false
      )
      let close = PetUnifiedRigRelationshipMotion.pose(
        pet: pet,
        gesture: .leanClose,
        elapsed: 1.2,
        reduceMotion: false
      )
      let sway = PetUnifiedRigRelationshipMotion.pose(
        pet: pet,
        gesture: .sharedSway,
        elapsed: 1.2,
        reduceMotion: false
      )
      let play = PetUnifiedRigRelationshipMotion.pose(
        pet: pet,
        gesture: .anticipatePlay,
        elapsed: 1.2,
        reduceMotion: false
      )

      #expect(abs(invite.frontLeading.y - invite.frontTrailing.y) > 1.5)
      #expect(close.frontLeading.x < 0)
      #expect(close.frontTrailing.x > 0)
      #expect(abs(sway.frontLeading.y - sway.frontTrailing.y) > 0.5)
      #expect(play.frontLeading.x < 0)
      #expect(play.frontTrailing.x > 0)
      #expect(play.frontLeading.y > 0)
      #expect(play.frontTrailing.y > 0)

      if pet == .pauli {
        #expect(invite.head != .neutral)
        #expect(close.head != .neutral)
        #expect(sway.head != .neutral)
        #expect(play.head.y < 0)
      } else {
        #expect(invite.head == .neutral)
        #expect(close.head == .neutral)
        #expect(sway.head == .neutral)
        #expect(play.head == .neutral)
      }
    }
  }

  @Test("relationship joints stay finite bounded and respect Reduce Motion")
  func relationshipJointsStaySafe() {
    for pet in PetKind.allCases {
      for gesture in PetRelationshipGesture.allCases {
        for elapsed in stride(
          from: 0.0,
          through: PetRelationshipGestureMotion.duration,
          by: 0.025
        ) {
          let pose = PetUnifiedRigRelationshipMotion.pose(
            pet: pet,
            gesture: gesture,
            elapsed: elapsed,
            reduceMotion: false
          )
          for joint in pose.joints {
            #expect(joint.x.isFinite)
            #expect(joint.y.isFinite)
            #expect(joint.rotationDegrees.isFinite)
            #expect(abs(joint.x) <= 5)
            #expect(abs(joint.y) <= 7)
            #expect(abs(joint.rotationDegrees) <= 12)
          }
        }
      }
    }

    #expect(
      PetUnifiedRigRelationshipMotion.pose(
        pet: .dog,
        gesture: .sharedSway,
        elapsed: 1.2,
        reduceMotion: true
      ) == .neutral)
  }

  @Test("direct touch braces the paws and returns to neutral")
  func directTouchBracesPawsAndReturnsToNeutral() {
    for pet in PetKind.allCases {
      let duration = PetAnimationDynamics.patDuration(comboCount: 1)
      let start = PetUnifiedRigDirectTouchMotion.pose(
        pet: pet,
        elapsed: 0,
        comboCount: 1,
        reduceMotion: false
      )
      let peak = PetUnifiedRigDirectTouchMotion.pose(
        pet: pet,
        elapsed: duration * 0.5,
        comboCount: 1,
        reduceMotion: false
      )
      let completed = PetUnifiedRigDirectTouchMotion.pose(
        pet: pet,
        elapsed: duration,
        comboCount: 1,
        reduceMotion: false
      )

      #expect(start == .neutral)
      #expect(completed == .neutral)
      #expect(peak.frontLeading.x < 0)
      #expect(peak.frontTrailing.x > 0)
      #expect(peak.frontLeading.y > 0)
      #expect(peak.frontTrailing.y > 0)
      if pet == .pauli {
        #expect(peak.head.y > 0)
      } else {
        #expect(peak.head == .neutral)
      }
    }
  }

  @Test("direct touch combos escalate while joints remain bounded")
  func directTouchCombosEscalateWithinBounds() {
    for pet in PetKind.allCases {
      let softDuration = PetAnimationDynamics.patDuration(comboCount: 1)
      let celebrationDuration = PetAnimationDynamics.patDuration(comboCount: 5)
      let soft = PetUnifiedRigDirectTouchMotion.pose(
        pet: pet,
        elapsed: softDuration * 0.5,
        comboCount: 1,
        reduceMotion: false
      )
      let celebration = PetUnifiedRigDirectTouchMotion.pose(
        pet: pet,
        elapsed: celebrationDuration * 0.5,
        comboCount: 5,
        reduceMotion: false
      )

      #expect(abs(celebration.frontLeading.x) > abs(soft.frontLeading.x))
      #expect(celebration.frontLeading.y > soft.frontLeading.y)

      for comboCount in [1, 3, 5] {
        let duration = PetAnimationDynamics.patDuration(comboCount: comboCount)
        for elapsed in stride(from: 0.0, through: duration, by: 0.02) {
          let pose = PetUnifiedRigDirectTouchMotion.pose(
            pet: pet,
            elapsed: elapsed,
            comboCount: comboCount,
            reduceMotion: false
          )
          for joint in pose.joints {
            #expect(joint.x.isFinite)
            #expect(joint.y.isFinite)
            #expect(joint.rotationDegrees.isFinite)
            #expect(abs(joint.x) <= 5)
            #expect(abs(joint.y) <= 7)
            #expect(abs(joint.rotationDegrees) <= 12)
          }
        }
      }
    }
  }

  @Test("Reduce Motion keeps direct-touch joints neutral")
  func reduceMotionKeepsDirectTouchJointsNeutral() {
    #expect(
      PetUnifiedRigDirectTouchMotion.pose(
        pet: .dog,
        elapsed: 0.2,
        comboCount: 5,
        reduceMotion: true
      ) == .neutral)
  }

  @Test("idle micro-actions mirror the head and lifted paw")
  func idleMicroActionsMirrorHeadAndPaw() {
    for pet in PetKind.allCases {
      let first = PetMotionDirector.previewFrame(
        pet: pet,
        event: .idleAction1,
        time: 0.8,
        reduceMotion: false
      )
      let second = PetMotionDirector.previewFrame(
        pet: pet,
        event: .idleAction2,
        time: 0.8,
        reduceMotion: false
      )
      let firstPose = PetUnifiedRigMotion.pose(
        pet: pet,
        motion: first,
        rootMotion: nil,
        reduceMotion: false
      )
      let secondPose = PetUnifiedRigMotion.pose(
        pet: pet,
        motion: second,
        rootMotion: nil,
        reduceMotion: false
      )

      if pet == .pauli {
        #expect(firstPose.head.x < 0)
        #expect(secondPose.head.x > 0)
        #expect(
          firstPose.head.rotationDegrees
            == -secondPose.head.rotationDegrees
        )
      } else {
        #expect(firstPose.head == .neutral)
        #expect(secondPose.head == .neutral)
      }
      #expect(firstPose.frontLeading.y < firstPose.frontTrailing.y)
      #expect(secondPose.frontTrailing.y < secondPose.frontLeading.y)
    }
  }

  @Test("look-around moves the head between distinct held directions")
  func lookAroundMovesHeadBetweenHolds() {
    for pet in PetKind.allCases {
      let firstHold = PetMotionDirector.previewFrame(
        pet: pet,
        event: .lookAround,
        time: 0.8,
        reduceMotion: false
      )
      let secondHold = PetMotionDirector.previewFrame(
        pet: pet,
        event: .lookAround,
        time: 2.08,
        reduceMotion: false
      )
      let firstPose = PetUnifiedRigMotion.pose(
        pet: pet,
        motion: firstHold,
        rootMotion: nil,
        reduceMotion: false
      )
      let secondPose = PetUnifiedRigMotion.pose(
        pet: pet,
        motion: secondHold,
        rootMotion: nil,
        reduceMotion: false
      )

      if pet == .pauli {
        #expect(firstPose.head.x < 0)
        #expect(secondPose.head.x > 0)
        #expect(firstPose.head.rotationDegrees < 0)
        #expect(secondPose.head.rotationDegrees > 0)
      } else {
        #expect(firstPose.head == .neutral)
        #expect(secondPose.head == .neutral)
      }
      #expect(firstPose.frontLeading.x < 0)
      #expect(secondPose.frontLeading.x > 0)
    }
  }

  @Test("perk-up lifts the head and braces both front paws")
  func perkUpLiftsHeadAndBracesPaws() {
    for pet in PetKind.allCases {
      let start = PetMotionDirector.previewFrame(
        pet: pet,
        event: .perkUp,
        time: 0,
        reduceMotion: false
      )
      let peak = PetMotionDirector.previewFrame(
        pet: pet,
        event: .perkUp,
        time: 0.9,
        reduceMotion: false
      )
      let startPose = PetUnifiedRigMotion.pose(
        pet: pet,
        motion: start,
        rootMotion: nil,
        reduceMotion: false
      )
      let peakPose = PetUnifiedRigMotion.pose(
        pet: pet,
        motion: peak,
        rootMotion: nil,
        reduceMotion: false
      )

      #expect(startPose == .neutral)
      if pet == .pauli {
        #expect(peakPose.head.y < 0)
      } else {
        #expect(peakPose.head == .neutral)
      }
      #expect(peakPose.frontLeading.x < 0)
      #expect(peakPose.frontTrailing.x > 0)
    }
  }

  @Test("walking alternates planted and swinging limbs")
  func walkingAlternatesLimbs() {
    for pet in PetKind.allCases {
      let cadence = PetMotionDirector.cadence(for: pet, seed: 0)
      let firstQuarter = PetMotionDirector.previewFrame(
        pet: pet,
        event: .walk,
        time: 0.25 / cadence.stepsPerSecond,
        reduceMotion: false
      )
      let thirdQuarter = PetMotionDirector.previewFrame(
        pet: pet,
        event: .walk,
        time: 0.75 / cadence.stepsPerSecond,
        reduceMotion: false
      )

      let firstPose = PetUnifiedRigMotion.pose(
        pet: pet,
        motion: firstQuarter,
        rootMotion: nil,
        reduceMotion: false
      )
      let thirdPose = PetUnifiedRigMotion.pose(
        pet: pet,
        motion: thirdQuarter,
        rootMotion: nil,
        reduceMotion: false
      )

      #expect(firstPose.frontLeading.y < firstPose.frontTrailing.y)
      #expect(thirdPose.frontTrailing.y < thirdPose.frontLeading.y)
      #expect(firstPose.frontLeading.rotationDegrees > 0)
      #expect(thirdPose.frontLeading.rotationDegrees < 0)
    }
  }

  @Test("root transitions stay continuous and settle to neutral")
  func rootTransitionsSettleToNeutral() {
    for direction in [PetRootMotionDirection.left, .right] {
      let plan = PetRootMotionPlan.resolve(
        startX: 500,
        visibleMinX: 0,
        visibleMaxX: 1440,
        windowWidth: 260,
        desiredDistance: 120,
        preferredDirection: direction
      )
      let completed = plan.frame(at: plan.duration)

      for pet in PetKind.allCases {
        let pose = PetUnifiedRigMotion.pose(
          pet: pet,
          motion: .idle,
          rootMotion: completed,
          reduceMotion: false
        )
        #expect(pose == .neutral)
      }
    }
  }

  @Test("all sampled joint transforms are finite and bounded")
  func jointTransformsAreFiniteAndBounded() {
    let plan = PetRootMotionPlan.resolve(
      startX: 500,
      visibleMinX: 0,
      visibleMaxX: 1440,
      windowWidth: 260,
      desiredDistance: 120,
      preferredDirection: .left
    )

    for pet in PetKind.allCases {
      for elapsed in stride(from: 0.0, through: plan.duration, by: 0.025) {
        let rootMotion = plan.frame(at: elapsed)
        let motion = PetMotionDirector.rootMotionFrame(
          pet: pet,
          rootMotion: rootMotion,
          reduceMotion: false
        )
        let pose = PetUnifiedRigMotion.pose(
          pet: pet,
          motion: motion,
          rootMotion: rootMotion,
          reduceMotion: false
        )

        for joint in pose.joints {
          #expect(joint.x.isFinite)
          #expect(joint.y.isFinite)
          #expect(joint.rotationDegrees.isFinite)
          #expect(abs(joint.x) <= 5)
          #expect(abs(joint.y) <= 7)
          #expect(abs(joint.rotationDegrees) <= 12)
        }
      }
    }
  }

  @Test("moving-region masks isolate articulated parts from the torso")
  func movingRegionMasksStayBodySafe() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    let fixtures: [(PetKind, PetRigLayer, CGPoint)] = [
      (.cat, .head, CGPoint(x: 40, y: 32)),
      (.cat, .frontLeading, CGPoint(x: 38, y: 82)),
      (.cat, .frontTrailing, CGPoint(x: 49, y: 82)),
      (.cat, .rear, CGPoint(x: 64, y: 72)),
      (.pauli, .head, CGPoint(x: 50, y: 30)),
      (.pauli, .frontLeading, CGPoint(x: 39, y: 84)),
      (.pauli, .frontTrailing, CGPoint(x: 59, y: 84)),
      (.dog, .head, CGPoint(x: 40, y: 40)),
      (.dog, .frontLeading, CGPoint(x: 35, y: 84)),
      (.dog, .frontTrailing, CGPoint(x: 53, y: 84)),
      (.dog, .rear, CGPoint(x: 66, y: 68)),
    ]

    for (pet, layer, includedPoint) in fixtures {
      let path = PetRigLayerMask(kind: pet, layer: layer).path(in: rect)
      #expect(path.contains(includedPoint))
      if layer == .head {
        #expect(!path.contains(CGPoint(x: 52, y: 75)))
      } else {
        #expect(!path.contains(CGPoint(x: 45, y: 30)))
        #expect(!path.contains(CGPoint(x: 52, y: 50)))
      }
    }

    let pauliRear = PetRigLayerMask(kind: .pauli, layer: .rear).path(in: rect)
    #expect(pauliRear.isEmpty)
  }

  @Test("body cutouts leave overlap beneath moving limb edges")
  func bodyCutoutsLeaveSeamOverlap() {
    let rect = CGRect(x: 0, y: 0, width: 190, height: 198)

    for pet in PetKind.allCases {
      for layer in PetRigLayer.allCases {
        let movingBounds = PetRigLayerMask(kind: pet, layer: layer)
          .path(in: rect)
          .boundingRect
        let cutoutBounds = PetRigLayerCutoutMask(kind: pet, layer: layer)
          .path(in: rect)
          .boundingRect
        guard !movingBounds.isEmpty else {
          #expect(cutoutBounds.isEmpty)
          continue
        }

        #expect(cutoutBounds.minX > movingBounds.minX)
        #expect(cutoutBounds.maxX < movingBounds.maxX)
        #expect(cutoutBounds.minY > movingBounds.minY)
        if layer == .head {
          #expect(cutoutBounds.minX - movingBounds.minX >= 4)
          #expect(movingBounds.maxX - cutoutBounds.maxX >= 4)
          #expect(cutoutBounds.minY - movingBounds.minY >= 4)
          #expect(movingBounds.maxY - cutoutBounds.maxY >= 4)
          #expect(cutoutBounds.maxY < movingBounds.maxY)
        } else {
          #expect(abs(cutoutBounds.maxY - movingBounds.maxY) < 0.001)
        }
      }
    }
  }

  @Test("reduce motion returns a neutral rig pose")
  func reduceMotionUsesNeutralPose() {
    let walk = PetMotionDirector.previewFrame(
      pet: .dog,
      event: .walk,
      time: 0.4,
      reduceMotion: false
    )
    #expect(
      PetUnifiedRigMotion.pose(
        pet: .dog,
        motion: walk,
        rootMotion: nil,
        reduceMotion: true
      ) == .neutral)
  }
}
