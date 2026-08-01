import Testing
@testable import DeskPetCore

@Suite("Observed weather scenes")
struct WeatherObservationTests {
    @Test("measured precipitation scales density within the render budget")
    func precipitationScalesDensity() {
        let drizzle = WeatherSnapshot(
            conditionCode: 61,
            temperatureCelsius: 16,
            locationName: "Shanghai",
            details: WeatherDetails(
                precipitationMillimeters: 0.1,
                rainMillimeters: 0.1,
                cloudCoverPercent: 80,
                windSpeedKilometersPerHour: 5,
                isDay: true
            )
        )
        let downpour = WeatherSnapshot(
            conditionCode: 82,
            temperatureCelsius: 16,
            locationName: "Shanghai",
            details: WeatherDetails(
                precipitationMillimeters: 8,
                rainMillimeters: 8,
                cloudCoverPercent: 100,
                windSpeedKilometersPerHour: 42,
                isDay: true
            )
        )

        let lightProfile = WeatherSceneProfile(snapshot: drizzle)
        let heavyProfile = WeatherSceneProfile(snapshot: downpour)

        #expect(heavyProfile.precipitationIntensity > lightProfile.precipitationIntensity)
        #expect(heavyProfile.totalParticleCount > lightProfile.totalParticleCount)
        #expect(heavyProfile.totalParticleCount <= 40)
        #expect(heavyProfile.foreground.speed > lightProfile.foreground.speed)
    }

    @Test("meteorological wind direction controls horizontal screen drift")
    func windDirectionControlsDrift() {
        let eastWind = WeatherDetails(
            windSpeedKilometersPerHour: 30,
            windDirectionDegrees: 90
        )
        let westWind = WeatherDetails(
            windSpeedKilometersPerHour: 30,
            windDirectionDegrees: 270
        )

        let eastProfile = WeatherSceneProfile(mood: .rainy, details: eastWind)
        let westProfile = WeatherSceneProfile(mood: .rainy, details: westWind)

        #expect(eastProfile.wind < 0)
        #expect(westProfile.wind > 0)
        #expect(abs(eastProfile.wind + westProfile.wind) < 0.000_001)
    }

    @Test("visibility humidity and cloud cover shape atmosphere")
    func atmosphericMeasurementsShapeScene() {
        let clear = WeatherSceneProfile(
            mood: .foggy,
            details: WeatherDetails(
                relativeHumidityPercent: 45,
                cloudCoverPercent: 15,
                visibilityMeters: 20_000,
                isDay: true
            )
        )
        let dense = WeatherSceneProfile(
            mood: .foggy,
            details: WeatherDetails(
                relativeHumidityPercent: 98,
                cloudCoverPercent: 100,
                visibilityMeters: 350,
                isDay: false
            )
        )

        #expect(dense.fogDensity > clear.fogDensity)
        #expect(dense.cloudDensity > clear.cloudDensity)
        #expect(!dense.isDaylight)
        #expect(clear.isDaylight)
    }

    @Test("scene cadence stays suitable for an always-on companion")
    func renderCadenceIsBounded() {
        for mood in PetWeatherMood.allCases {
            #expect(WeatherSceneProfile(mood: mood).maximumFramesPerSecond <= 30)
        }
    }

    @Test("invalid measurements fall back to safe normalized values")
    func invalidMeasurementsAreSafe() {
        let profile = WeatherSceneProfile(
            mood: .stormy,
            details: WeatherDetails(
                relativeHumidityPercent: .nan,
                precipitationMillimeters: .infinity,
                cloudCoverPercent: -.infinity,
                windSpeedKilometersPerHour: .nan,
                windDirectionDegrees: .infinity,
                visibilityMeters: -.infinity,
                isDay: false
            )
        )

        for value in [
            profile.precipitationIntensity,
            profile.cloudDensity,
            profile.fogDensity,
            profile.windStrength,
            profile.gustStrength,
        ] {
            #expect(value.isFinite)
            #expect((0...1).contains(value))
        }
        #expect(profile.wind.isFinite)
        #expect(profile.totalParticleCount <= 40)
    }
}
