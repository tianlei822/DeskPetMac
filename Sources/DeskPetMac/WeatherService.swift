import DeskPetCore
import Foundation

struct WeatherService {
    func currentWeather(for place: CurrentPlace) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(
                name: "current",
                value: [
                    "temperature_2m",
                    "relative_humidity_2m",
                    "apparent_temperature",
                    "is_day",
                    "precipitation",
                    "rain",
                    "snowfall",
                    "weather_code",
                    "cloud_cover",
                    "wind_speed_10m",
                    "wind_direction_10m",
                    "wind_gusts_10m",
                    "visibility",
                ].joined(separator: ",")
            ),
        ]

        let url = components.url!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try Self.snapshot(from: data, locationName: place.name)
    }

    static func snapshot(
        from data: Data,
        locationName: String,
        observedAt: Date = Date()
    ) throws -> WeatherSnapshot {
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        return WeatherSnapshot(
            conditionCode: response.current.weatherCode,
            temperatureCelsius: response.current.temperature,
            locationName: locationName,
            observedAt: observedAt,
            details: WeatherDetails(
                apparentTemperatureCelsius: response.current.apparentTemperature,
                relativeHumidityPercent: response.current.relativeHumidity,
                precipitationMillimeters: response.current.precipitation,
                rainMillimeters: response.current.rain,
                snowfallCentimeters: response.current.snowfall,
                cloudCoverPercent: response.current.cloudCover,
                windSpeedKilometersPerHour: response.current.windSpeed,
                windDirectionDegrees: response.current.windDirection,
                windGustKilometersPerHour: response.current.windGusts,
                visibilityMeters: response.current.visibility,
                isDay: response.current.isDay.map { $0 == 1 }
            )
        )
    }
}

private struct OpenMeteoResponse: Decodable {
    let current: Current

    struct Current: Decodable {
        let temperature: Double
        let weatherCode: Int
        let relativeHumidity: Double?
        let apparentTemperature: Double?
        let isDay: Int?
        let precipitation: Double?
        let rain: Double?
        let snowfall: Double?
        let cloudCover: Double?
        let windSpeed: Double?
        let windDirection: Double?
        let windGusts: Double?
        let visibility: Double?

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
            case relativeHumidity = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case isDay = "is_day"
            case precipitation
            case rain
            case snowfall
            case cloudCover = "cloud_cover"
            case windSpeed = "wind_speed_10m"
            case windDirection = "wind_direction_10m"
            case windGusts = "wind_gusts_10m"
            case visibility
        }
    }
}
