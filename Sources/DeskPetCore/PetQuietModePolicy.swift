public enum PetPresentationKind: Equatable, Sendable {
    case directInteraction
    case status
    case reminder
    case personality
}

public enum PetQuietModePolicy {
    public static func allows(
        _ presentation: PetPresentationKind,
        isQuietModeEnabled: Bool
    ) -> Bool {
        guard isQuietModeEnabled else { return true }
        return presentation == .directInteraction
    }
}
