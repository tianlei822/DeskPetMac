import AppKit
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
