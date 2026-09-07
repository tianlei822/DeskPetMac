import Testing
@testable import DeskPetCore

@Suite("Continuous pet motion")
struct PetContinuousMotionTests {
    @Test("interruptions preserve position and velocity")
    func interruption() {
        var motion = PetDampedValue(value: 0)
        for _ in 0..<12 { motion.advance(toward: 10, deltaTime: 1 / 60.0) }
        let position = motion.value
        let velocity = motion.velocity
        motion.advance(toward: -10, deltaTime: 0)
        #expect(motion.value == position)
        #expect(motion.velocity == velocity)
        motion.advance(toward: -10, deltaTime: 1 / 60.0)
        #expect(abs(motion.value - position) < 1)
        for _ in 0..<180 { motion.advance(toward: -10, deltaTime: 1 / 60.0) }
        #expect(abs(motion.value + 10) < 0.001)
    }

    @Test("settling is independent of display cadence")
    func cadence() {
        var slow = PetDampedValue(value: 0)
        var fast = slow
        for _ in 0..<30 { slow.advance(toward: 1, deltaTime: 1 / 30.0) }
        for _ in 0..<60 { fast.advance(toward: 1, deltaTime: 1 / 60.0) }
        #expect(abs(slow.value - fast.value) < 0.000001)
        #expect(slow.value > 0.99 && slow.value <= 1)
    }

    @Test("invalid samples cannot poison presentation")
    func invalidSamples() {
        var motion = PetDampedValue(value: 2)
        motion.advance(toward: .nan, deltaTime: 0.1)
        motion.advance(toward: 3, deltaTime: .infinity)
        #expect(motion.value == 2)
        #expect(motion.velocity == 0)
    }

    @Test("Pauli's wide screen accepts touch without capturing the empty top corner")
    func screenHitRegion() {
        #expect(PetHitMask.contains(normalizedPoint: .init(x: 0.80, y: 0.30), petKind: .pauli))
        #expect(!PetHitMask.contains(normalizedPoint: .init(x: 0.80, y: 0.10), petKind: .pauli))
        #expect(PetInteractionMap.resolve(normalizedPoint: .init(x: 0.80, y: 0.20), petKind: .pauli) == .head)
    }
}
