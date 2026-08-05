import DeskPetCore
import SwiftUI

@MainActor
protocol PetWindowDragRouting: AnyObject {
    func allowsWindowDrag(at point: NSPoint) -> Bool
}

private enum PetHostingLayout {
    static let canvasSize = CGSize(width: 260, height: 290)
    static let artworkOriginFromTop = CGPoint(x: 20, y: 48)
    static let artworkSize = CGSize(width: 220, height: 218)
}

@MainActor
final class PetHostingView<Content: View>: NSHostingView<Content>, PetWindowDragRouting {
    private let model: PetViewModel

    init(rootView: Content, model: PetViewModel) {
        self.model = model
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init(rootView: Content) {
        fatalError("Use init(rootView:model:)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(rootView:model:)")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard acceptsPointer(at: point) else { return nil }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func acceptsPointer(at point: NSPoint) -> Bool {
        guard bounds.width > 0,
              bounds.height > 0,
              bounds.contains(point) else { return false }

        let normalizedPoint = CGPoint(
            x: (point.x - bounds.minX) / bounds.width,
            y: 1 - (point.y - bounds.minY) / bounds.height
        )

        if model.isReminderVisible, normalizedPoint.y <= 0.36 {
            return true
        }

        if model.activeToyKind != nil {
            let toyPoint = CGPoint(
                x: (20 + model.toyPosition.x * 220) / 260,
                y: (48 + model.toyPosition.y * 218) / 290
            )
            let horizontal = (normalizedPoint.x - toyPoint.x) / 0.10
            let vertical = (normalizedPoint.y - toyPoint.y) / 0.09
            if horizontal * horizontal + vertical * vertical <= 1 {
                return true
            }
        }

        return PetHitMask.contains(
            normalizedPoint: normalizedPoint,
            petKind: model.petKind
        )
    }

    func allowsWindowDrag(at point: NSPoint) -> Bool {
        guard bounds.width > 0,
              bounds.height > 0,
              bounds.contains(point) else { return false }

        let normalizedWindowPoint = CGPoint(
            x: (point.x - bounds.minX) / bounds.width,
            y: 1 - (point.y - bounds.minY) / bounds.height
        )
        if model.isReminderVisible, normalizedWindowPoint.y <= 0.36 {
            return false
        }
        if model.activeToyKind != nil {
            let toyPoint = CGPoint(
                x: (20 + model.toyPosition.x * 220) / 260,
                y: (48 + model.toyPosition.y * 218) / 290
            )
            let horizontal = (normalizedWindowPoint.x - toyPoint.x) / 0.10
            let vertical = (normalizedWindowPoint.y - toyPoint.y) / 0.09
            if horizontal * horizontal + vertical * vertical <= 1 {
                return false
            }
        }

        let artworkPoint = normalizedArtworkPoint(at: point)
        guard (0...1).contains(artworkPoint.x),
              (0...1).contains(artworkPoint.y) else { return true }
        return !PetStrokeGestureResolver.isScratchCandidate(
            at: artworkPoint,
            petKind: model.petKind
        )
    }

    private func normalizedArtworkPoint(at point: NSPoint) -> CGPoint {
        let scaleX = bounds.width / PetHostingLayout.canvasSize.width
        let scaleY = bounds.height / PetHostingLayout.canvasSize.height
        let pointFromTop = bounds.maxY - point.y
        return CGPoint(
            x: (point.x - bounds.minX - PetHostingLayout.artworkOriginFromTop.x * scaleX)
                / (PetHostingLayout.artworkSize.width * scaleX),
            y: (pointFromTop - PetHostingLayout.artworkOriginFromTop.y * scaleY)
                / (PetHostingLayout.artworkSize.height * scaleY)
        )
    }
}
