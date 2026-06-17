import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestCurrentPlace() async -> CurrentPlace? {
        let status = await ensureAuthorized()
        guard status == .authorizedAlways else { return nil }
        guard let location = await requestOneShotLocation() else { return nil }
        let placemark = try? await geocoder.reverseGeocodeLocation(location).first
        let name = placemark?.locality
            ?? placemark?.administrativeArea
            ?? placemark?.country
            ?? "Local"

        return CurrentPlace(
            name: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    private func ensureAuthorized() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestOneShotLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }
}

struct CurrentPlace: Equatable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard let continuation = authContinuation else { return }
            authContinuation = nil
            continuation.resume(returning: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        MainActor.assumeIsolated {
            guard let continuation = locationContinuation else { return }
            locationContinuation = nil
            continuation.resume(returning: latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            guard let continuation = locationContinuation else { return }
            locationContinuation = nil
            continuation.resume(returning: nil)
        }
    }
}
