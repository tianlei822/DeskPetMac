import SwiftUI

private struct PetWindowVisibilityKey: EnvironmentKey {
    static let defaultValue = true
}

private struct PetRenderTimeOverrideKey: EnvironmentKey {
    static let defaultValue: TimeInterval? = nil
}

private struct PetAttentionElapsedOverrideKey: EnvironmentKey {
    static let defaultValue: TimeInterval? = nil
}

private struct PetRelationshipGestureElapsedOverrideKey: EnvironmentKey {
    static let defaultValue: TimeInterval? = nil
}

extension EnvironmentValues {
    var petWindowIsVisible: Bool {
        get { self[PetWindowVisibilityKey.self] }
        set { self[PetWindowVisibilityKey.self] = newValue }
    }

    var petRenderTimeOverride: TimeInterval? {
        get { self[PetRenderTimeOverrideKey.self] }
        set { self[PetRenderTimeOverrideKey.self] = newValue }
    }

    var petAttentionElapsedOverride: TimeInterval? {
        get { self[PetAttentionElapsedOverrideKey.self] }
        set { self[PetAttentionElapsedOverrideKey.self] = newValue }
    }

    var petRelationshipGestureElapsedOverride: TimeInterval? {
        get { self[PetRelationshipGestureElapsedOverrideKey.self] }
        set { self[PetRelationshipGestureElapsedOverrideKey.self] = newValue }
    }
}
