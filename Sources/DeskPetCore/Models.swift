import Foundation

public enum PetWeatherMood: String, CaseIterable, Equatable, Sendable {
    case sunny
    case cloudy
    case foggy
    case rainy
    case snowy
    case stormy
    case cozy

    public init(openMeteoCode code: Int?) {
        guard let code else {
            self = .cozy
            return
        }

        switch code {
        case 0, 1:
            self = .sunny
        case 2, 3:
            self = .cloudy
        case 45, 48:
            self = .foggy
        case 51...67, 80...82:
            self = .rainy
        case 71...77, 85...86:
            self = .snowy
        case 95...99:
            self = .stormy
        default:
            self = .cozy
        }
    }

    public var displayName: String {
        switch self {
        case .sunny: "Sunny"
        case .cloudy: "Cloudy"
        case .foggy: "Foggy"
        case .rainy: "Rainy"
        case .snowy: "Snowy"
        case .stormy: "Stormy"
        case .cozy: "Cozy"
        }
    }

    public var petLine: String {
        switch self {
        case .sunny: "Sunbeam patrol."
        case .cloudy: "Soft cloud mode."
        case .foggy: "Tiny lantern on."
        case .rainy: "Rain boots ready."
        case .snowy: "Snow snack watch."
        case .stormy: "Brave little thunder buddy."
        case .cozy: "Desk nest secured."
        }
    }
}

public enum PetKind: String, CaseIterable, Equatable, Sendable {
    case cat
    case pauli

    public var displayName: String {
        switch self {
        case .cat: "Cat"
        case .pauli: "Pauli"
        }
    }
}

public struct WeatherSnapshot: Equatable, Sendable {
    public let conditionCode: Int?
    public let temperatureCelsius: Double?
    public let locationName: String
    public let observedAt: Date

    public init(
        conditionCode: Int?,
        temperatureCelsius: Double?,
        locationName: String,
        observedAt: Date = Date()
    ) {
        self.conditionCode = conditionCode
        self.temperatureCelsius = temperatureCelsius
        self.locationName = locationName
        self.observedAt = observedAt
    }

    public var mood: PetWeatherMood {
        PetWeatherMood(openMeteoCode: conditionCode)
    }

    public var temperatureLabel: String {
        guard let temperatureCelsius else { return "--" }
        return "\(Int(temperatureCelsius.rounded()))C"
    }

    public static let placeholder = WeatherSnapshot(
        conditionCode: nil,
        temperatureCelsius: nil,
        locationName: "Local"
    )
}

public struct WorkSessionState: Equatable, Codable, Sendable {
    public let activeSeconds: Int
    public let lastObservedAt: Date

    public init(activeSeconds: Int, lastObservedAt: Date) {
        self.activeSeconds = max(0, activeSeconds)
        self.lastObservedAt = lastObservedAt
    }
}

public struct BreakReminderState: Equatable, Codable, Sendable {
    public let activeSeconds: Int
    public let lastReminderAt: Date?
    public let snoozedUntil: Date?

    public init(activeSeconds: Int, lastReminderAt: Date?, snoozedUntil: Date?) {
        self.activeSeconds = max(0, activeSeconds)
        self.lastReminderAt = lastReminderAt
        self.snoozedUntil = snoozedUntil
    }
}
