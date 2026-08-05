import AppKit
import ColorSync
import Combine
import DeskPetCore
import SwiftUI

@MainActor
final class PetWindowDragGestureRecognizer: NSPanGestureRecognizer, NSGestureRecognizerDelegate {
    private weak var petWindow: NSWindow?
    private let onDragBegan: () -> Void
    private let shouldBeginAt: (NSPoint) -> Bool
    private var windowOriginAtDragStart: NSPoint?
    private var pointerLocationAtDragStart: NSPoint?
    private var gestureStartedAt: TimeInterval?
    private var hasActivatedWindowDrag = false

    init(
        window: NSWindow,
        onDragBegan: @escaping () -> Void = {},
        shouldBeginAt: @escaping (NSPoint) -> Bool = { _ in true }
    ) {
        petWindow = window
        self.onDragBegan = onDragBegan
        self.shouldBeginAt = shouldBeginAt
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
            let pointerNow = NSEvent.mouseLocation
            if !hasActivatedWindowDrag,
               let pointerLocationAtDragStart,
               let gestureStartedAt {
                let translation = CGSize(
                    width: pointerNow.x - pointerLocationAtDragStart.x,
                    height: pointerNow.y - pointerLocationAtDragStart.y
                )
                let now = NSApp.currentEvent?.timestamp
                    ?? ProcessInfo.processInfo.systemUptime
                if PetWindowDragPolicy.shouldActivate(
                    elapsed: max(0, now - gestureStartedAt),
                    translation: translation
                ) {
                    hasActivatedWindowDrag = true
                    onDragBegan()
                }
            }
            if hasActivatedWindowDrag,
               let windowOriginAtDragStart,
               let pointerLocationAtDragStart {
                petWindow.setFrameOrigin(
                    Self.windowOrigin(
                        startingAt: windowOriginAtDragStart,
                        pointerStartedAt: pointerLocationAtDragStart,
                        pointerNowAt: pointerNow
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
        let contentPoint = gestureRecognizer.view?.convert(
            event.locationInWindow,
            from: nil
        ) ?? event.locationInWindow
        guard shouldBeginAt(contentPoint) else { return false }
        captureDragStart(window: petWindow, pointerLocation: pointerLocation)
        gestureStartedAt = event.timestamp
        hasActivatedWindowDrag = false
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
        gestureStartedAt = nil
        hasActivatedWindowDrag = false
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = PetViewModel()

    private let petWindowSize = NSSize(width: 260, height: 290)
    private let positionStore = PetWindowPositionStore()
    private var petPanel: PetPanel?
    private var screenParametersObserver: NSObjectProtocol?
    private var windowOcclusionObserver: NSObjectProtocol?
    private var rootMotionCancellable: AnyCancellable?
    private var rootMotionTask: Task<Void, Never>?
    private var positionPersistenceTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        showPetWindow()
        observeScreenChanges()
        observeRootMotionRequests()
        Task { await model.start() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.persistSession()
        positionPersistenceTask?.cancel()
        persistPosition()
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
        if let windowOcclusionObserver {
            NotificationCenter.default.removeObserver(windowOcclusionObserver)
        }
        rootMotionTask?.cancel()
        rootMotionCancellable?.cancel()
    }

    func configurePetWindow(_ window: NSWindow) {
        window.title = "DeskPet"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = window is NSPanel
            ? [.borderless, .fullSizeContentView, .nonactivatingPanel]
            : [.borderless, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        if let panel = window as? NSPanel {
            panel.becomesKeyOnlyIfNeeded = true
            panel.hidesOnDeactivate = false
        }
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

    private func installDragGesture(on window: NSWindow) {
        guard let contentView = window.contentView,
              !contentView.gestureRecognizers.contains(where: {
                  $0 is PetWindowDragGestureRecognizer
              }) else { return }

        contentView.addGestureRecognizer(PetWindowDragGestureRecognizer(
            window: window,
            onDragBegan: { [weak self] in
                self?.model.cancelRootMotion()
            },
            shouldBeginAt: { [weak contentView] point in
                guard let routing = contentView as? PetWindowDragRouting else {
                    return true
                }
                return routing.allowsWindowDrag(at: point)
            }
        ))
    }

    func windowDidMove(_ notification: Notification) {
        guard let movedWindow = notification.object as? NSWindow,
              movedWindow === petPanel,
              model.rootMotionRequest == nil else { return }
        schedulePositionPersistence()
    }

    private func showPetWindow() {
        if let petPanel {
            petPanel.orderFrontRegardless()
            return
        }

        let panel = PetPanel(
            contentRect: NSRect(origin: .zero, size: petWindowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let rootView = PetWindowView(model: model)
            .frame(width: petWindowSize.width, height: petWindowSize.height)
        let hostingView = PetHostingView(rootView: rootView, model: model)
        hostingView.frame = NSRect(origin: .zero, size: petWindowSize)
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        petPanel = panel
        restorePosition(of: panel)
        configurePetWindow(panel)
        observeOcclusion(of: panel)
    }

    private func observeScreenChanges() {
        guard screenParametersObserver == nil else { return }
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let panel = self.petPanel else { return }
                self.positionPersistenceTask?.cancel()
                self.positionPersistenceTask = nil
                self.model.cancelRootMotion()
                self.restorePosition(of: panel)
            }
        }
    }

    private func observeOcclusion(of window: NSWindow) {
        guard windowOcclusionObserver == nil else { return }
        updateVisibility(of: window)
        windowOcclusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            Task { @MainActor [weak self] in
                self?.updateVisibility(of: window)
            }
        }
    }

    private func updateVisibility(of window: NSWindow) {
        model.setPetWindowVisible(
            DeskPetDiagnosticOverrides.interactionLoopEnabled()
                || (window.isVisible && window.occlusionState.contains(.visible))
        )
    }

    private func observeRootMotionRequests() {
        rootMotionCancellable = model.$rootMotionRequest.sink {
            [weak self] request in
            Task { @MainActor [weak self] in
                self?.handleRootMotionRequest(request)
            }
        }
    }

    private func handleRootMotionRequest(_ request: PetRootMotionRequest?) {
        rootMotionTask?.cancel()
        rootMotionTask = nil
        guard let request else { return }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            model.completeRootMotion(id: request.id)
            return
        }
        guard let panel = petPanel,
              let screen = panel.screen else { return }

        let plan = PetRootMotionPlan.resolve(
            startX: panel.frame.minX,
            visibleMinX: screen.visibleFrame.minX,
            visibleMaxX: screen.visibleFrame.maxX,
            windowWidth: panel.frame.width,
            desiredDistance: request.desiredDistance,
            preferredDirection: request.preferredDirection
        )
        guard plan.distance > 0 else {
            model.completeRootMotion(id: request.id)
            return
        }

        let fixedY = panel.frame.minY
        rootMotionTask = Task { @MainActor [weak self, weak panel] in
            let startedAt = Date().timeIntervalSinceReferenceDate
            while !Task.isCancelled {
                guard let self,
                      let panel,
                      self.model.rootMotionRequest?.id == request.id else { return }
                let elapsed = Date().timeIntervalSinceReferenceDate - startedAt
                let frame = plan.frame(at: elapsed)
                self.model.updateRootMotion(id: request.id, frame: frame)
                panel.setFrameOrigin(NSPoint(x: frame.windowX, y: fixedY))
                if frame.phase == .completed {
                    self.persistPosition()
                    self.model.completeRootMotion(id: request.id)
                    return
                }
                do {
                    try await Task.sleep(for: .seconds(1.0 / 30.0))
                } catch {
                    return
                }
            }
        }
    }

    private func persistPosition() {
        guard let panel = petPanel,
              let screen = panel.screen else { return }
        let identity = screenIdentity(for: screen)
        let anchor = PetWindowAnchor.capture(
            windowFrame: panel.frame,
            visibleFrame: screen.visibleFrame
        )
        positionStore.save(
            anchor: anchor,
            screenID: identity.id
        )
    }

    private func schedulePositionPersistence() {
        positionPersistenceTask?.cancel()
        positionPersistenceTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(180))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.persistPosition()
            self?.positionPersistenceTask = nil
        }
    }

    private func restorePosition(of window: NSWindow) {
        let screens = NSScreen.screens
        let snapshots = screens.map(screenSnapshot(for:))
        var anchorsByScreenID: [String: PetWindowAnchor] = [:]
        for snapshot in snapshots {
            anchorsByScreenID[snapshot.id] = positionStore.anchor(
                for: snapshot.id,
                legacyScreenIDs: snapshot.legacyIDs
            )
        }

        let preferredScreenID = positionStore.lastScreenID
        let fallbackAnchor = preferredScreenID.flatMap(positionStore.anchor(for:))
        let mainScreenID = NSScreen.main.map { screenIdentity(for: $0).id }
        guard let placement = PetWindowPlacementResolver.resolve(
            windowFrame: window.frame,
            windowSize: window.frame.size,
            screens: snapshots,
            preferredScreenID: preferredScreenID,
            mainScreenID: mainScreenID,
            anchorsByScreenID: anchorsByScreenID,
            fallbackAnchor: fallbackAnchor
        ) else { return }

        window.setFrameOrigin(placement.origin)
        positionStore.save(
            anchor: placement.anchor,
            screenID: placement.screenID
        )
    }

    private func screenSnapshot(for screen: NSScreen) -> PetWindowScreenSnapshot {
        let identity = screenIdentity(for: screen)
        return PetWindowScreenSnapshot(
            id: identity.id,
            legacyIDs: identity.legacyIDs,
            visibleFrame: screen.visibleFrame
        )
    }

    private func screenIdentity(for screen: NSScreen) -> PetDisplayIdentity {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        let number = screen.deviceDescription[key] as? NSNumber
        return PetDisplayIdentity.resolve(
            stableID: number.flatMap(stableDisplayID(for:)),
            legacyID: number?.stringValue,
            localizedName: screen.localizedName
        )
    }

    private func stableDisplayID(for number: NSNumber) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?
            .takeRetainedValue(),
              let uuidString = CFUUIDCreateString(nil, uuid)
        else { return nil }
        return "display-\(uuidString as String)"
    }
}
