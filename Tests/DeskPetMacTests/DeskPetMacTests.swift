import AppKit
import DeskPetCore
import Testing
@testable import DeskPetMac

@Suite("DeskPet app lifecycle")
struct DeskPetAppLifecycleTests {
    @Test("startup can only be claimed once")
    func startupCanOnlyBeClaimedOnce() {
        var gate = PetStartupGate()
        let firstClaim = gate.claim()
        let secondClaim = gate.claim()
        let thirdClaim = gate.claim()

        #expect(firstClaim)
        #expect(!secondClaim)
        #expect(!thirdClaim)
    }

    @Test("window configuration brings the pet onscreen")
    @MainActor
    func windowConfigurationBringsPetOnscreen() {
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 260, height: 290),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let delegate = AppDelegate()

        delegate.configurePetWindow(window)

        #expect(window.isVisible)
        #expect(window.level == .floating)
        window.orderOut(nil)
    }

    @Test("window configuration installs one drag gesture")
    @MainActor
    func windowConfigurationInstallsOneDragGesture() {
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 260, height: 290),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let delegate = AppDelegate()

        delegate.configurePetWindow(window)
        delegate.configurePetWindow(window)

        let dragGestures = window.contentView?.gestureRecognizers.filter {
            $0 is PetWindowDragGestureRecognizer
        }
        #expect(dragGestures?.count == 1)
        window.orderOut(nil)
    }

    @Test("screen-space drag preserves the exact pointer distance")
    @MainActor
    func screenSpaceDragPreservesExactPointerDistance() {
        let origin = PetWindowDragGestureRecognizer.windowOrigin(
            startingAt: NSPoint(x: 120, y: 120),
            pointerStartedAt: NSPoint(x: 320, y: 200),
            pointerNowAt: NSPoint(x: 380, y: 240)
        )

        #expect(origin == NSPoint(x: 180, y: 160))
    }
}

@Suite("Vector pet motion values")
struct VectorPetMotionValuesTests {
    @Test("Reduce Motion keeps Pauli status brightness static")
    func reduceMotionKeepsPauliStatusStatic() {
        let first = VectorPetMotionValues.pauliStatusPulse(
            time: 0,
            reduceMotion: true
        )
        let later = VectorPetMotionValues.pauliStatusPulse(
            time: 10,
            reduceMotion: true
        )

        #expect(first == later)
        #expect(first == 1)
    }
}

@Suite("Pet artwork blending")
struct PetArtworkBlendTests {
    @Test("motion artwork crossfade keeps total opacity normalized")
    func motionArtworkCrossfadeKeepsOpacityNormalized() {
        let motion = PetMotionFrame(
            event: .walk,
            artworkFrameIndex: 2,
            nextArtworkFrameIndex: 3,
            artworkBlend: 0.25,
            artworkOpacity: 0.8,
            stepCount: 3,
            eventProgress: 0.5,
            horizontalOffset: 0,
            verticalOffset: 0,
            tiltDegrees: 0,
            shadowScale: 1,
            shadowOffset: 0
        )

        let blend = PetArtworkBlend(motion: motion)

        #expect(abs(blend.baseOpacity - 0.2) < 0.000_001)
        #expect(abs(blend.currentOpacity - 0.6) < 0.000_001)
        #expect(abs(blend.nextOpacity - 0.2) < 0.000_001)
        #expect(abs(
            blend.baseOpacity + blend.currentOpacity + blend.nextOpacity - 1
        ) < 0.000_001)
    }
}

@Suite("Pet artwork animation policy")
struct PetArtworkAnimationPolicyTests {
    @Test("alternate pose artwork stays in one layer")
    func alternatePoseArtworkStaysWhole() {
        for pet in [PetKind.cat, .dog] {
            #expect(!PetArtworkAnimationPolicy.usesIndependentTailLayer(
                for: pet,
                reduceMotion: false,
                isSleeping: false,
                isHovering: true,
                isShowingPat: false,
                hasPersonalityPose: false
            ))
            #expect(!PetArtworkAnimationPolicy.usesIndependentTailLayer(
                for: pet,
                reduceMotion: false,
                isSleeping: false,
                isHovering: false,
                isShowingPat: true,
                hasPersonalityPose: false
            ))
            #expect(!PetArtworkAnimationPolicy.usesIndependentTailLayer(
                for: pet,
                reduceMotion: false,
                isSleeping: false,
                isHovering: false,
                isShowingPat: false,
                hasPersonalityPose: true
            ))
        }
    }

    @Test("base cat and dog artwork can animate the tail independently")
    func baseArtworkCanAnimateTail() {
        for pet in [PetKind.cat, .dog] {
            #expect(PetArtworkAnimationPolicy.usesIndependentTailLayer(
                for: pet,
                reduceMotion: false,
                isSleeping: false,
                isHovering: false,
                isShowingPat: false,
                hasPersonalityPose: false
            ))
        }
        #expect(!PetArtworkAnimationPolicy.usesIndependentTailLayer(
            for: .pauli,
            reduceMotion: false,
            isSleeping: false,
            isHovering: false,
            isShowingPat: false,
            hasPersonalityPose: false
        ))
    }
}

@Suite("Pet artwork crossfade")
struct PetArtworkCrossfadeTests {
    @Test("blend endpoints swap layers and stay normalized")
    func blendEndpoints() {
        let start = PetArtworkCrossfade(progress: 0)
        #expect(start.currentOpacity == 0)
        #expect(start.outgoingOpacity == 1)

        let end = PetArtworkCrossfade(progress: 1)
        #expect(end.currentOpacity == 1)
        #expect(end.outgoingOpacity == 0)

        for progress in stride(from: -0.5, through: 1.5, by: 0.05) {
            let fade = PetArtworkCrossfade(progress: progress)
            #expect(abs(fade.currentOpacity + fade.outgoingOpacity - 1) < 0.000_001)
            #expect((0...1).contains(fade.currentOpacity))
            #expect((0...1).contains(fade.outgoingOpacity))
        }

        let nonFinite = PetArtworkCrossfade(progress: .nan)
        #expect(nonFinite.currentOpacity == 1)
        #expect(nonFinite.outgoingOpacity == 0)
    }

    @Test("transition store blends between presented artworks")
    @MainActor
    func transitionStoreLifecycle() {
        let store = PetArtworkTransitionStore()
        var layers = store.layers(for: "Pets/Cat/base", at: 100, animated: true)
        #expect(layers.current == "Pets/Cat/base")
        #expect(layers.currentOpacity == 1)
        #expect(layers.outgoing == nil)

        layers = store.layers(for: "Pets/Cat/blink", at: 101, animated: true)
        #expect(layers.current == "Pets/Cat/blink")
        #expect(layers.outgoing == "Pets/Cat/base")
        #expect(layers.currentOpacity == 0)
        #expect(layers.outgoingOpacity == 1)

        let mid = store.layers(
            for: "Pets/Cat/blink",
            at: 101 + PetArtworkTransitionStore.blinkDuration / 2,
            animated: true
        )
        #expect(mid.outgoing == "Pets/Cat/base")
        #expect(mid.currentOpacity > 0)
        #expect(mid.currentOpacity < 1)

        let done = store.layers(
            for: "Pets/Cat/blink",
            at: 101 + PetArtworkTransitionStore.blinkDuration + 0.01,
            animated: true
        )
        #expect(done.outgoing == nil)
        #expect(done.currentOpacity == 1)
    }

    @Test("blink transitions complete quicker than standard ones")
    @MainActor
    func blinkTransitionIsQuicker() {
        #expect(
            PetArtworkTransitionStore.blinkDuration
                < PetArtworkTransitionStore.standardDuration
        )
        let store = PetArtworkTransitionStore()
        _ = store.layers(for: "Pets/Cat/base", at: 0, animated: true)
        let blink = store.layers(for: "Pets/Cat/blink", at: 1, animated: true)
        #expect(blink.outgoing == "Pets/Cat/base")

        let afterBlink = store.layers(
            for: "Pets/Cat/blink",
            at: 1 + PetArtworkTransitionStore.blinkDuration + 0.005,
            animated: true
        )
        #expect(afterBlink.outgoing == nil)
    }

    @Test("unanimated requests switch instantly")
    @MainActor
    func unanimatedSwitchesInstantly() {
        let store = PetArtworkTransitionStore()
        _ = store.layers(for: "a", at: 0, animated: true)
        let layers = store.layers(for: "b", at: 1, animated: false)
        #expect(layers.current == "b")
        #expect(layers.currentOpacity == 1)
        #expect(layers.outgoing == nil)
    }
}
