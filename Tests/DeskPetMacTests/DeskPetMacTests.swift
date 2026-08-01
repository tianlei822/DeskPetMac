import AppKit
import DeskPetCore
import Foundation
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

@Suite("Weather service decoding")
struct WeatherServiceDecodingTests {
    @Test("current observations retain atmospheric detail")
    func currentObservationsRetainDetail() throws {
        let json = """
        {
          "current": {
            "temperature_2m": 18.5,
            "relative_humidity_2m": 92,
            "apparent_temperature": 17.2,
            "is_day": 0,
            "precipitation": 3.4,
            "rain": 3.1,
            "snowfall": 0,
            "weather_code": 63,
            "cloud_cover": 96,
            "wind_speed_10m": 27,
            "wind_direction_10m": 245,
            "wind_gusts_10m": 43,
            "visibility": 1800
          }
        }
        """
        let observedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = try WeatherService.snapshot(
            from: Data(json.utf8),
            locationName: "Shanghai",
            observedAt: observedAt
        )

        #expect(snapshot.temperatureCelsius == 18.5)
        #expect(snapshot.locationName == "Shanghai")
        #expect(snapshot.observedAt == observedAt)
        #expect(snapshot.details.relativeHumidityPercent == 92)
        #expect(snapshot.details.apparentTemperatureCelsius == 17.2)
        #expect(snapshot.details.precipitationMillimeters == 3.4)
        #expect(snapshot.details.rainMillimeters == 3.1)
        #expect(snapshot.details.cloudCoverPercent == 96)
        #expect(snapshot.details.windSpeedKilometersPerHour == 27)
        #expect(snapshot.details.windDirectionDegrees == 245)
        #expect(snapshot.details.windGustKilometersPerHour == 43)
        #expect(snapshot.details.visibilityMeters == 1800)
        #expect(snapshot.details.isDay == false)
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
    @Test("motion artwork presents only one whole raster at a time")
    func motionArtworkNeverOverlapsWholeRasters() {
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

        #expect(blend.baseOpacity == 0)
        #expect((PetArtworkBlend.minimumBridgeOpacity...1).contains(
            blend.currentOpacity
        ))
        #expect(blend.nextOpacity == 0)

        let entering = PetArtworkBlend(motion: PetMotionFrame(
            event: .walk,
            artworkFrameIndex: 0,
            artworkOpacity: 0.25,
            stepCount: 3,
            eventProgress: 0.02,
            horizontalOffset: 0,
            verticalOffset: 0,
            tiltDegrees: 0,
            shadowScale: 1,
            shadowOffset: 0
        ))
        #expect((PetArtworkBlend.minimumBridgeOpacity...1).contains(
            entering.baseOpacity
        ))
        #expect(entering.currentOpacity == 0)
        #expect(entering.nextOpacity == 0)
    }
}

@Suite("Pet tail artwork")
struct PetTailArtworkTests {
    @Test("only aligned idle artwork can use independent tail layers")
    func independentTailArtworkStaysScoped() {
        for kind in [PetKind.cat, .dog] {
            let manifest = PetArtworkManifest(petKind: kind)
            #expect(PetTailArtworkPolicy.supportsIndependentTail(
                kind: kind,
                resourceName: manifest.base
            ))
            #expect(PetTailArtworkPolicy.supportsIndependentTail(
                kind: kind,
                resourceName: manifest.blink
            ))
            #expect(!PetTailArtworkPolicy.supportsIndependentTail(
                kind: kind,
                resourceName: manifest.walk[0]
            ))
            #expect(!PetTailArtworkPolicy.supportsIndependentTail(
                kind: kind,
                resourceName: manifest.hover
            ))
        }

        let pauli = PetArtworkManifest(petKind: .pauli)
        #expect(!PetTailArtworkPolicy.supportsIndependentTail(
            kind: .pauli,
            resourceName: pauli.base
        ))
    }

    @Test("cat and dog tails use distinct bounded flexible motion")
    func tailMotionIsCharacterSpecific() {
        var catRootMaximum = 0.0
        var catTipMaximum = 0.0
        var dogRootMaximum = 0.0
        var dogTipMaximum = 0.0

        for time in stride(from: 0.0, through: 20.0, by: 0.025) {
            let cat = PetTailMotion.pose(
                for: .cat,
                time: time,
                energy: 0.7,
                curiosity: 0.9,
                socialNeed: 0.4
            )
            let dog = PetTailMotion.pose(
                for: .dog,
                time: time,
                energy: 0.7,
                curiosity: 0.4,
                socialNeed: 0.9
            )

            #expect(cat.midDegrees.isFinite)
            #expect(cat.tipDegrees.isFinite)
            #expect(dog.midDegrees.isFinite)
            #expect(dog.tipDegrees.isFinite)
            #expect(abs(cat.midDegrees) <= 4.5)
            #expect(abs(cat.tipDegrees) <= 8.5)
            #expect(abs(dog.midDegrees) <= 8.5)
            #expect(abs(dog.tipDegrees) <= 12.5)

            catRootMaximum = max(catRootMaximum, abs(cat.midDegrees))
            catTipMaximum = max(catTipMaximum, abs(cat.tipDegrees))
            dogRootMaximum = max(dogRootMaximum, abs(dog.midDegrees))
            dogTipMaximum = max(dogTipMaximum, abs(dog.tipDegrees))
        }

        #expect(catTipMaximum > catRootMaximum)
        #expect(dogTipMaximum > dogRootMaximum)
        #expect(dogRootMaximum > catRootMaximum)
    }

    @Test("tail masks include tail segments and exclude head and torso")
    func tailMasksStayHeadSafe() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

        let catMoving = PetTailMask(kind: .cat, segment: .movingRegion)
            .path(in: rect)
        let catMiddle = PetTailMask(kind: .cat, segment: .middle)
            .path(in: rect)
        let catTip = PetTailMask(kind: .cat, segment: .tip)
            .path(in: rect)
        #expect(catMoving.contains(CGPoint(x: 69, y: 22)))
        #expect(catMoving.contains(CGPoint(x: 58, y: 8)))
        #expect(catMiddle.contains(CGPoint(x: 69, y: 22)))
        #expect(catTip.contains(CGPoint(x: 58, y: 8)))
        #expect(!catMoving.contains(CGPoint(x: 42, y: 30)))
        #expect(!catMoving.contains(CGPoint(x: 70, y: 60)))

        let dogMoving = PetTailMask(kind: .dog, segment: .movingRegion)
            .path(in: rect)
        let dogMiddle = PetTailMask(kind: .dog, segment: .middle)
            .path(in: rect)
        let dogTip = PetTailMask(kind: .dog, segment: .tip)
            .path(in: rect)
        #expect(dogMoving.contains(CGPoint(x: 56, y: 19)))
        #expect(dogMoving.contains(CGPoint(x: 50, y: 8)))
        #expect(dogMiddle.contains(CGPoint(x: 56, y: 19)))
        #expect(dogTip.contains(CGPoint(x: 50, y: 8)))
        #expect(!dogMoving.contains(CGPoint(x: 42, y: 35)))
        #expect(!dogMoving.contains(CGPoint(x: 55, y: 55)))
    }

    @Test("invalid tail inputs fall back to a neutral finite pose")
    func invalidTailInputsAreSafe() {
        let pose = PetTailMotion.pose(
            for: .dog,
            time: .nan,
            energy: .infinity,
            curiosity: -.infinity,
            socialNeed: .nan
        )
        #expect(pose == .neutral)
    }
}

@Suite("Pet eye tracking")
struct PetEyeTrackingTests {
    @Test("pointer direction uses a dead zone and stays inside the unit circle")
    func pointerDirectionIsBounded() {
        #expect(PetEyeGazeMotion.direction(for: .zero) == .zero)
        #expect(PetEyeGazeMotion.direction(
            for: CGSize(width: 0.03, height: -0.02)
        ) == .zero)

        let right = PetEyeGazeMotion.direction(
            for: CGSize(width: 2, height: 0)
        )
        #expect(abs(right.width - 1) < 0.000_001)
        #expect(abs(right.height) < 0.000_001)

        let diagonal = PetEyeGazeMotion.direction(
            for: CGSize(width: -1, height: 1)
        )
        #expect(diagonal.width < 0)
        #expect(diagonal.height > 0)
        #expect(hypot(diagonal.width, diagonal.height) <= 1.000_001)
    }

    @Test("invalid pointer values fall back to neutral gaze")
    func invalidPointerIsNeutral() {
        #expect(PetEyeGazeMotion.direction(
            for: CGSize(width: CGFloat.nan, height: 0)
        ) == .zero)
        #expect(PetEyeGazeMotion.direction(
            for: CGSize(width: 0, height: CGFloat.infinity)
        ) == .zero)
    }

    @Test("eye tracking is limited to aligned open-eye artwork")
    func eyeArtworkPolicyStaysScoped() {
        for kind in PetKind.allCases {
            let manifest = PetArtworkManifest(petKind: kind)
            #expect(PetEyeArtworkPolicy.pose(
                kind: kind,
                resourceName: manifest.base
            ) == .base)
            #expect(PetEyeArtworkPolicy.pose(
                kind: kind,
                resourceName: manifest.hover
            ) == .hover)
            #expect(PetEyeArtworkPolicy.pose(
                kind: kind,
                resourceName: manifest.blink
            ) == nil)
            #expect(PetEyeArtworkPolicy.pose(
                kind: kind,
                resourceName: manifest.walk[0]
            ) == nil)
        }
    }

    @Test("every eye layout is finite separated and stays on the artwork")
    func eyeLayoutsStayValid() {
        for kind in PetKind.allCases {
            for pose in PetEyeArtworkPose.allCases {
                let layout = PetEyeLayout.layout(for: kind, pose: pose)
                #expect((0...1).contains(layout.leftCenter.x))
                #expect((0...1).contains(layout.leftCenter.y))
                #expect((0...1).contains(layout.rightCenter.x))
                #expect((0...1).contains(layout.rightCenter.y))
                #expect(layout.leftCenter.x < layout.rightCenter.x)
                #expect(layout.pupilSize.width > 0)
                #expect(layout.pupilSize.height > 0)
                #expect((0...3).contains(layout.maximumTravel.width))
                #expect((0...3).contains(layout.maximumTravel.height))
            }
        }
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

    @Test("pose changes use a non-overlapping opacity bridge")
    @MainActor
    func poseChangesNeverOverlapWholeRasters() {
        let store = PetArtworkTransitionStore()
        _ = store.layers(for: "Pets/Cat/base", at: 0, animated: true)
        _ = store.layers(for: "Pets/Cat/pat", at: 1, animated: true)

        let outgoing = store.layers(
            for: "Pets/Cat/pat",
            at: 1 + PetArtworkTransitionStore.standardDuration * 0.25,
            animated: true
        )
        #expect(outgoing.currentOpacity == 0)
        #expect((PetArtworkBlend.minimumBridgeOpacity...1).contains(
            outgoing.outgoingOpacity
        ))

        let incoming = store.layers(
            for: "Pets/Cat/pat",
            at: 1 + PetArtworkTransitionStore.standardDuration * 0.75,
            animated: true
        )
        #expect(incoming.outgoingOpacity == 0)
        #expect((PetArtworkBlend.minimumBridgeOpacity...1).contains(
            incoming.currentOpacity
        ))
    }

    @Test("interrupting a blink with a pose does not crossfade mismatched heads")
    @MainActor
    func blinkInterruptedByPoseUsesBridge() {
        let store = PetArtworkTransitionStore()
        _ = store.layers(for: "Pets/Cat/base", at: 0, animated: true)
        _ = store.layers(for: "Pets/Cat/blink", at: 1, animated: true)
        _ = store.layers(
            for: "Pets/Cat/pat",
            at: 1 + PetArtworkTransitionStore.blinkDuration * 0.25,
            animated: true
        )

        let bridge = store.layers(
            for: "Pets/Cat/pat",
            at: 1 + PetArtworkTransitionStore.blinkDuration * 0.25
                + PetArtworkTransitionStore.standardDuration * 0.25,
            animated: true
        )
        #expect(bridge.currentOpacity == 0)
        #expect(bridge.outgoingOpacity > 0)
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

@Suite("Pet motion context latch")
struct PetMotionContextLatchTests {
    @Test("autonomy changes wait for an idle boundary")
    func autonomyChangesWaitForIdle() {
        let curious = PetAutonomyState(
            energy: 0.9,
            curiosity: 0.9,
            socialNeed: 0.2,
            focusPressure: 0.1,
            weatherInterest: 0.3,
            dominantDrive: .explore
        )
        var latch = PetMotionContextLatch(activeState: .neutral)

        let activatedDuringWalk = latch.observe(curious, while: .walk)
        #expect(!activatedDuringWalk)
        #expect(latch.activeState == .neutral)
        let activatedAtBoundary = latch.reachedIdleBoundary()
        #expect(activatedAtBoundary)
        #expect(latch.activeState == curious)
        let activatedAgain = latch.reachedIdleBoundary()
        #expect(!activatedAgain)
    }

    @Test("idle updates activate immediately and repeated values are ignored")
    func idleUpdatesActivateImmediately() {
        let attentive = PetAutonomyState(
            energy: 0.7,
            curiosity: 0.5,
            socialNeed: 0.9,
            focusPressure: 0.2,
            weatherInterest: 0.3,
            dominantDrive: .seekAttention
        )
        var latch = PetMotionContextLatch(activeState: .neutral)

        let activated = latch.observe(attentive, while: .idle)
        #expect(activated)
        #expect(latch.activeState == attentive)
        let repeated = latch.observe(attentive, while: .idle)
        #expect(!repeated)
    }
}
