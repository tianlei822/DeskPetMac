import DeskPetCore
import Foundation

enum DeskPetDiagnosticOverrides {
    static let weatherMoodKey = "deskpet.diagnostics.weatherMood"
    static let interactionLoopKey = "deskpet.diagnostics.interactionLoop"

    static func weatherMood(
        defaults: UserDefaults = .standard
    ) -> PetWeatherMood? {
        guard let rawValue = defaults.string(forKey: weatherMoodKey) else {
            return nil
        }
        return PetWeatherMood(rawValue: rawValue)
    }

    static func interactionLoopEnabled(
        defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.bool(forKey: interactionLoopKey)
    }
}
