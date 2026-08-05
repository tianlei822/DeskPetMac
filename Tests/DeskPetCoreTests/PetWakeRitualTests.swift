import Testing

@testable import DeskPetCore

@Suite("Pet wake ritual")
struct PetWakeRitualTests {
  @Test("a standard wake stretches before orienting")
  func standardWakeHasTwoCausalSteps() {
    let timing = PetWakeRitualTiming(
      stretchDuration: 0.72,
      orientDuration: 0.58,
      reducedMotionDuration: 0.32
    )

    let steps = PetWakeRitualPlanner.steps(
      timing: timing,
      reduceMotion: false
    )

    #expect(steps.map(\.phase) == [.stretching, .orienting])
    #expect(steps.map(\.pose) == [.stretch, .perk])
    #expect(steps.map(\.duration) == [0.72, 0.58])
  }

  @Test("Reduce Motion uses one short orienting pose")
  func reducedMotionSkipsStretchSequence() {
    let timing = PetWakeRitualTiming(
      stretchDuration: 0.72,
      orientDuration: 0.58,
      reducedMotionDuration: 0.32
    )

    let steps = PetWakeRitualPlanner.steps(
      timing: timing,
      reduceMotion: true
    )

    #expect(steps.count == 1)
    #expect(steps[0].phase == .orienting)
    #expect(steps[0].pose == .perk)
    #expect(steps[0].duration == 0.32)
  }

  @Test("waking sits above sleep but below explicit personality")
  func wakingHasCorrectActivityPriority() {
    let waking = PetActivityGraph.resolve(
      PetActivityContext(
        isSleeping: true,
        wakePose: .stretch,
        autonomyDrive: .rest
      ))
    let personality = PetActivityGraph.resolve(
      PetActivityContext(
        isSleeping: true,
        wakePose: .stretch,
        personalityPose: .proud,
        autonomyDrive: .rest
      ))

    #expect(waking.kind == .waking)
    #expect(waking.personalityPose == .stretch)
    #expect(personality.kind == .personality)
    #expect(personality.personalityPose == .proud)
  }

  @Test("invalid timing values resolve to finite positive durations")
  func timingIsSafe() {
    let timing = PetWakeRitualTiming(
      stretchDuration: .nan,
      orientDuration: -.infinity,
      reducedMotionDuration: 0
    )
    let steps = PetWakeRitualPlanner.steps(
      timing: timing,
      reduceMotion: false
    )

    #expect(steps.allSatisfy { $0.duration.isFinite })
    #expect(steps.allSatisfy { $0.duration > 0 })
  }
}
