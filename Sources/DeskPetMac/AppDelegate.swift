import AppKit

@MainActor
final class PetWindowDragGestureRecognizer: NSPanGestureRecognizer, NSGestureRecognizerDelegate {
    private weak var petWindow: NSWindow?
    private var windowOriginAtDragStart: NSPoint?
    private var pointerLocationAtDragStart: NSPoint?

    init(window: NSWindow) {
        petWindow = window
        super.init(target: nil, action: nil)
        target = self
        action = #selector(handleDrag)
        delegate = self
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func handleDrag() {
        guard let petWindow else { return }

        switch state {
        case .began, .changed, .ended:
            if windowOriginAtDragStart == nil || pointerLocationAtDragStart == nil {
                captureDragStart(window: petWindow, pointerLocation: NSEvent.mouseLocation)
            }
            if let windowOriginAtDragStart, let pointerLocationAtDragStart {
                petWindow.setFrameOrigin(
                    Self.windowOrigin(
                        startingAt: windowOriginAtDragStart,
                        pointerStartedAt: pointerLocationAtDragStart,
                        pointerNowAt: NSEvent.mouseLocation
                    )
                )
            }
            if state == .ended {
                clearDragStart()
            }
        case .cancelled, .failed:
            clearDragStart()
        default:
            break
        }
    }

    static func windowOrigin(
        startingAt windowOrigin: NSPoint,
        pointerStartedAt startPointer: NSPoint,
        pointerNowAt currentPointer: NSPoint
    ) -> NSPoint {
        NSPoint(
            x: windowOrigin.x + currentPointer.x - startPointer.x,
            y: windowOrigin.y + currentPointer.y - startPointer.y
        )
    }

    func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldAttemptToRecognizeWith event: NSEvent
    ) -> Bool {
        guard let petWindow else { return false }

        let pointerLocation = event.window?.convertPoint(
            toScreen: event.locationInWindow
        ) ?? NSEvent.mouseLocation
        captureDragStart(window: petWindow, pointerLocation: pointerLocation)
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
    ) -> Bool {
        true
    }

    private func captureDragStart(window: NSWindow, pointerLocation: NSPoint) {
        windowOriginAtDragStart = window.frame.origin
        pointerLocationAtDragStart = pointerLocation
    }

    private func clearDragStart() {
        windowOriginAtDragStart = nil
        pointerLocationAtDragStart = nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.async {
            self.configurePetWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.configurePetWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @MainActor
    private func configurePetWindow() {
        guard let window = NSApp.windows.first else { return }
        configurePetWindow(window)
    }

    @MainActor
    func configurePetWindow(_ window: NSWindow) {
        window.title = "DeskPet"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.borderless, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        installDragGesture(on: window)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        if window.frame.origin == .zero, let screen = NSScreen.main {
            let frame = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: frame.maxX - 320, y: frame.minY + 120))
        }

        window.orderFrontRegardless()
    }

    @MainActor
    private func installDragGesture(on window: NSWindow) {
        guard let contentView = window.contentView,
              !contentView.gestureRecognizers.contains(where: {
                  $0 is PetWindowDragGestureRecognizer
              }) else { return }

        contentView.addGestureRecognizer(PetWindowDragGestureRecognizer(window: window))
    }
}
