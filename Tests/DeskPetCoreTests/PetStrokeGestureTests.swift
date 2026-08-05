import Foundation
import Testing
@testable import DeskPetCore

@Suite("Pet stroke gestures")
struct PetStrokeGestureTests {
    @Test("slow strokes near an ear become scratches")
    func earStrokeBecomesScratch() {
        let gesture = PetStrokeGestureResolver.resolve(
            start: CGPoint(x: 0.33, y: 0.25),
            end: CGPoint(x: 0.37, y: 0.27),
            duration: 0.45,
            petKind: .cat
        )

        #expect(gesture == .scratch(.earOrTemple))
    }

    @Test("slow strokes under the face become chin scratches")
    func chinStrokeBecomesScratch() {
        let gesture = PetStrokeGestureResolver.resolve(
            start: CGPoint(x: 0.48, y: 0.47),
            end: CGPoint(x: 0.52, y: 0.50),
            duration: 0.42,
            petKind: .dog
        )

        #expect(gesture == .scratch(.chin))
    }

    @Test("quick strokes preserve direction and useful intensity")
    func quickStrokeBecomesSwipe() {
        let gesture = PetStrokeGestureResolver.resolve(
            start: CGPoint(x: 0.24, y: 0.62),
            end: CGPoint(x: 0.76, y: 0.64),
            duration: 0.18,
            petKind: .pauli
        )

        guard case .swipe(let direction, let intensity) = gesture else {
            Issue.record("Expected a swipe")
            return
        }
        #expect(direction == .right)
        #expect(intensity > 0.7)
        #expect(intensity <= 1)
    }

    @Test("slow torso drags do not impersonate a swipe or scratch")
    func slowTorsoDragIsIgnored() {
        let gesture = PetStrokeGestureResolver.resolve(
            start: CGPoint(x: 0.30, y: 0.68),
            end: CGPoint(x: 0.70, y: 0.70),
            duration: 1.1,
            petKind: .cat
        )

        #expect(gesture == .none)
    }

    @Test("invalid geometry safely resolves to none")
    func invalidGeometryIsIgnored() {
        #expect(PetStrokeGestureResolver.resolve(
            start: CGPoint(x: .nan, y: 0.2),
            end: CGPoint(x: 0.4, y: .infinity),
            duration: -1,
            petKind: .dog
        ) == .none)
    }

    @Test("scratch anchors can reserve the gesture for direct touch")
    func scratchAnchorsReserveDirectTouch() {
        #expect(PetStrokeGestureResolver.isScratchCandidate(
            at: CGPoint(x: 0.33, y: 0.25),
            petKind: .cat
        ))
        #expect(!PetStrokeGestureResolver.isScratchCandidate(
            at: CGPoint(x: 0.50, y: 0.78),
            petKind: .cat
        ))
    }

    @Test("a back-and-forth path remains a scratch when it returns near its start")
    func returningPathBecomesScratch() {
        var tracker = PetStrokePathTracker(
            start: CGPoint(x: 0.33, y: 0.25),
            timestamp: 10
        )
        tracker.append(CGPoint(x: 0.39, y: 0.26), timestamp: 10.12)
        tracker.append(CGPoint(x: 0.31, y: 0.24), timestamp: 10.24)
        tracker.append(CGPoint(x: 0.38, y: 0.27), timestamp: 10.36)
        tracker.append(CGPoint(x: 0.33, y: 0.25), timestamp: 10.50)

        #expect(tracker.path.reversalCount >= 2)
        #expect(tracker.path.travelDistance > 0.20)
        #expect(PetStrokeGestureResolver.resolve(
            path: tracker.path,
            petKind: .cat
        ) == .scratch(.earOrTemple))
    }

    @Test("a straight sampled path remains a directional swipe")
    func sampledStraightPathBecomesSwipe() {
        var tracker = PetStrokePathTracker(
            start: CGPoint(x: 0.20, y: 0.62),
            timestamp: 20
        )
        tracker.append(CGPoint(x: 0.40, y: 0.63), timestamp: 20.06)
        tracker.append(CGPoint(x: 0.62, y: 0.63), timestamp: 20.12)
        tracker.append(CGPoint(x: 0.82, y: 0.64), timestamp: 20.18)

        guard case .swipe(let direction, let intensity) =
            PetStrokeGestureResolver.resolve(
                path: tracker.path,
                petKind: .pauli
            )
        else {
            Issue.record("Expected sampled path to remain a swipe")
            return
        }
        #expect(direction == .right)
        #expect(intensity > 0.7)
    }

    @Test("back-and-forth movement on the torso does not impersonate a scratch")
    func torsoOscillationIsIgnored() {
        var tracker = PetStrokePathTracker(
            start: CGPoint(x: 0.40, y: 0.72),
            timestamp: 30
        )
        tracker.append(CGPoint(x: 0.55, y: 0.70), timestamp: 30.15)
        tracker.append(CGPoint(x: 0.42, y: 0.73), timestamp: 30.30)
        tracker.append(CGPoint(x: 0.57, y: 0.71), timestamp: 30.45)
        tracker.append(CGPoint(x: 0.43, y: 0.72), timestamp: 30.60)

        #expect(PetStrokeGestureResolver.resolve(
            path: tracker.path,
            petKind: .dog
        ) == .none)
    }

    @Test("tiny pointer jitter remains below the interaction threshold")
    func tinyJitterIsIgnored() {
        var tracker = PetStrokePathTracker(
            start: CGPoint(x: 0.33, y: 0.25),
            timestamp: 40
        )
        tracker.append(CGPoint(x: 0.335, y: 0.252), timestamp: 40.20)
        tracker.append(CGPoint(x: 0.331, y: 0.249), timestamp: 40.40)

        #expect(PetStrokeGestureResolver.resolve(
            path: tracker.path,
            petKind: .cat
        ) == .none)
    }
}

@Suite("Pet window drag policy")
struct PetWindowDragPolicyTests {
    @Test("quick swipes and small scratches do not move the window")
    func directGesturesStayLocal() {
        #expect(!PetWindowDragPolicy.shouldActivate(
            elapsed: 0.18,
            translation: CGSize(width: 60, height: 2)
        ))
        #expect(!PetWindowDragPolicy.shouldActivate(
            elapsed: 0.8,
            translation: CGSize(width: 20, height: 12)
        ))
    }

    @Test("deliberate sustained drags move the companion")
    func deliberateDragActivates() {
        #expect(PetWindowDragPolicy.shouldActivate(
            elapsed: 0.4,
            translation: CGSize(width: 48, height: 24)
        ))
    }

    @Test("invalid timing or geometry stays inactive")
    func invalidInputStaysInactive() {
        #expect(!PetWindowDragPolicy.shouldActivate(
            elapsed: .nan,
            translation: CGSize(width: 50, height: 0)
        ))
        #expect(!PetWindowDragPolicy.shouldActivate(
            elapsed: 1,
            translation: CGSize(width: CGFloat.infinity, height: 0)
        ))
    }
}
