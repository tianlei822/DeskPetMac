import AppKit
import DeskPetCore

/// Watches the mouse globally and reports a normalized offset from the pet
/// window's center so the pet can notice the cursor approaching. Receive-only
/// monitors — no accessibility permission required.
@MainActor
final class CursorTracker {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastHandledAt = Date.distantPast
    private var attentionTracker = PetAttentionTracker()

    private static let minimumInterval: TimeInterval = 1.0 / 30.0
    private static let attentionRadius: Double = 480
    private static let fullLeanDistance: Double = 260

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .mouseMoved
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseMoved()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .mouseMoved
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseMoved()
            }
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        attentionTracker.observe(
            offset: nil,
            at: Date().timeIntervalSinceReferenceDate
        )
    }

    /// Offset relative to the window center in the -1...1 range, y positive
    /// down (matching SwiftUI), plus time since entering the attention radius.
    func attentionSample(at time: TimeInterval) -> PetAttentionSample? {
        attentionTracker.sample(at: time)
    }

    private func handleMouseMoved() {
        let now = Date()
        guard now.timeIntervalSince(lastHandledAt) >= Self.minimumInterval else { return }
        lastHandledAt = now

        guard let window = NSApp.windows.first(where: { $0.isVisible })
            ?? NSApp.windows.first else {
            attentionTracker.observe(
                offset: nil,
                at: now.timeIntervalSinceReferenceDate
            )
            return
        }

        let pointer = NSEvent.mouseLocation
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let dx = pointer.x - center.x
        let dy = pointer.y - center.y
        guard hypot(dx, dy) <= Self.attentionRadius else {
            attentionTracker.observe(
                offset: nil,
                at: now.timeIntervalSinceReferenceDate
            )
            return
        }

        attentionTracker.observe(
            offset: CGSize(
                width: Self.clampUnit(dx / Self.fullLeanDistance),
                height: Self.clampUnit(-dy / Self.fullLeanDistance)
            ),
            at: now.timeIntervalSinceReferenceDate
        )
    }

    private static func clampUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(-1, value))
    }
}
