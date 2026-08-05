import DeskPetCore
import Foundation

struct PetWindowPositionStore {
    private enum Key {
        static let anchorPrefix = "deskpet.window.anchor."
        static let lastScreenID = "deskpet.window.lastScreenID"
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastScreenID: String? {
        defaults.string(forKey: Key.lastScreenID)
    }

    func anchor(for screenID: String) -> PetWindowAnchor? {
        guard let data = defaults.data(
            forKey: Key.anchorPrefix + screenID
        ) else { return nil }
        return try? JSONDecoder().decode(PetWindowAnchor.self, from: data)
    }

    func anchor(
        for screenID: String,
        legacyScreenIDs: [String]
    ) -> PetWindowAnchor? {
        if let anchor = anchor(for: screenID) {
            migrateLastScreenID(
                from: legacyScreenIDs,
                to: screenID
            )
            return anchor
        }

        for legacyScreenID in legacyScreenIDs where legacyScreenID != screenID {
            guard let anchor = anchor(for: legacyScreenID) else { continue }
            saveMigrated(anchor: anchor, screenID: screenID)
            migrateLastScreenID(from: [legacyScreenID], to: screenID)
            return anchor
        }
        return nil
    }

    func save(anchor: PetWindowAnchor, screenID: String) {
        guard let data = try? JSONEncoder().encode(anchor) else { return }
        defaults.set(data, forKey: Key.anchorPrefix + screenID)
        defaults.set(screenID, forKey: Key.lastScreenID)
    }

    private func saveMigrated(anchor: PetWindowAnchor, screenID: String) {
        guard let data = try? JSONEncoder().encode(anchor) else { return }
        defaults.set(data, forKey: Key.anchorPrefix + screenID)
    }

    private func migrateLastScreenID(from legacyIDs: [String], to screenID: String) {
        guard let lastScreenID, legacyIDs.contains(lastScreenID) else { return }
        defaults.set(screenID, forKey: Key.lastScreenID)
    }
}
