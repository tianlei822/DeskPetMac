import Foundation
import Testing
@testable import DeskPetCore

@Suite("Pet treat journey")
struct PetTreatJourneyTests {
    @Test("feeding progresses through every causal phase")
    func feedingUsesEveryPhase() {
        let journey = PetTreatJourney(
            start: CGPoint(x: 0.88, y: 0.08),
            landing: CGPoint(x: 0.28, y: 0.76),
            mouth: CGPoint(x: 0.48, y: 0.43)
        )
        let samples = stride(
            from: 0.0,
            through: journey.duration,
            by: journey.duration / 80
        ).map { journey.frame(at: $0).phase }

        #expect(samples.contains(.tossing))
        #expect(samples.contains(.watching))
        #expect(samples.contains(.approaching))
        #expect(samples.contains(.sniffing))
        #expect(samples.contains(.eating))
        #expect(samples.contains(.satisfied))
        #expect(samples.last == .completed)
    }

    @Test("toss arcs above its straight path before landing")
    func tossUsesAnArc() {
        let journey = PetTreatJourney(
            start: CGPoint(x: 0.85, y: 0.10),
            landing: CGPoint(x: 0.25, y: 0.76),
            mouth: CGPoint(x: 0.48, y: 0.43)
        )
        let tossMidpoint = journey.frame(
            at: journey.duration * 0.11
        )
        let straightMidpointY = (journey.start.y + journey.landing.y) / 2

        #expect(tossMidpoint.phase == .tossing)
        #expect(tossMidpoint.position.y < straightMidpointY)
        #expect(tossMidpoint.scale > 0)
        #expect(tossMidpoint.opacity == 1)
    }

    @Test("eating draws the treat to the mouth and consumes it")
    func eatingConsumesTreat() {
        let journey = PetTreatJourney(
            start: CGPoint(x: 0.85, y: 0.10),
            landing: CGPoint(x: 0.25, y: 0.76),
            mouth: CGPoint(x: 0.48, y: 0.43)
        )
        let eating = journey.frame(at: journey.duration * 0.76)
        let satisfied = journey.frame(at: journey.duration * 0.90)

        #expect(eating.phase == .eating)
        #expect(eating.position.x > journey.landing.x)
        #expect(eating.position.y < journey.landing.y)
        #expect(eating.scale < 1)
        #expect(satisfied.phase == .satisfied)
        #expect(satisfied.opacity == 0)
    }

    @Test("invalid points are clamped into the scene")
    func invalidGeometryIsSafe() {
        let journey = PetTreatJourney(
            start: CGPoint(x: CGFloat.nan, y: -2),
            landing: CGPoint(x: 3, y: CGFloat.infinity),
            mouth: CGPoint(x: 0.5, y: 0.4)
        )

        for elapsed in stride(from: 0.0, through: journey.duration, by: 0.1) {
            let frame = journey.frame(at: elapsed)
            #expect(frame.position.x.isFinite)
            #expect(frame.position.y.isFinite)
            #expect((0...1).contains(frame.position.x))
            #expect((0...1).contains(frame.position.y))
            #expect(frame.scale.isFinite)
            #expect(frame.opacity.isFinite)
        }
    }
}
