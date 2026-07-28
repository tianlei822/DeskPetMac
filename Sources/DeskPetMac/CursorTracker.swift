import AppKit

/// Watches the mouse globally and reports a normalized offset from the pet
/// window's center so the pet can notice the cursor approaching. Receive-only
/// monitors — no accessibility permission required.
@MainActor
final class CursorTracker {
    /// Offset relative to the window center in the -1...1 range, y positive
    /// down (matching SwiftUI). `nil` when the cursor is far away.
    private(set) var normalizedOffset: CGSize?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastHandledAt = Date.distantPast

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
        normalizedOffset = nil
    }

    private func handleMouseMoved() {
        let now = Date()
        guard now.timeIntervalSince(lastHandledAt) >= Self.minimumInterval else { return }
        lastHandledAt = now

        guard let window = NSApp.windows.first(where: { $0.isVisible })
            ?? NSApp.windows.first else {
            normalizedOffset = nil
            return
        }

        let pointer = NSEvent.mouseLocation
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let dx = pointer.x - center.x
        let dy = pointer.y - center.y
        guard hypot(dx, dy) <= Self.attentionRadius else {
            normalizedOffset = nil
            return
        }

        normalizedOffset = CGSize(
            width: Self.clampUnit(dx / Self.fullLeanDistance),
            height: Self.clampUnit(-dy / Self.fullLeanDistance)
        )
    }

    private static func clampUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(-1, value))
    }
}
