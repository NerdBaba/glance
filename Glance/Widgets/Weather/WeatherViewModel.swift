import CoreLocation
import Foundation

final class WeatherViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var temperature: Double?
    @Published var apparentTemperature: Double?
    @Published var weatherCode: Int = 0
    @Published var humidity: Int = 0
    @Published var windSpeed: Double = 0
    @Published var forecast: [DayForecast] = []
    @Published var locationName: String = ""
    @Published var isLoading = true

    struct DayForecast: Identifiable {
        let id = UUID()
        let date: Date
        let weatherCode: Int
        let tempMax: Double
        let tempMin: Double
    }

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var timer: Timer?
    private var lastCoordinate: CLLocationCoordinate2D?
    private var didAttemptFallback = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer

        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            // On macOS, startUpdatingLocation triggers the system permission prompt
            locationManager.startUpdatingLocation()
        } else if status == .denied || status == .restricted {
            fallbackToIPGeolocation()
        } else {
            locationManager.startUpdatingLocation()
        }
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorized || status == .authorizedAlways {
            manager.startUpdatingLocation()
        } else if status == .denied || status == .restricted {
            if !didAttemptFallback {
                fallbackToIPGeolocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationManager.stopUpdatingLocation()
        lastCoordinate = location.coordinate
        reverseGeocode(location)
        fetchWeather(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        startRefreshTimer()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if !didAttemptFallback {
            fallbackToIPGeolocation()
        }
    }

    // MARK: - IP Geolocation Fallback

    private func fallbackToIPGeolocation() {
        didAttemptFallback = true
        guard let url = URL(string: "https://ipapi.co/json/") else {
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                DispatchQueue.main.async { self?.isLoading = false }
                return
            }
            do {
                let geo = try JSONDecoder().decode(IPGeoResponse.self, from: data)
                DispatchQueue.main.async {
                    self.lastCoordinate = CLLocationCoordinate2D(
                        latitude: geo.latitude, longitude: geo.longitude)
                    self.locationName = geo.city ?? ""
                    self.fetchWeather(lat: geo.latitude, lon: geo.longitude)
                    self.startRefreshTimer()
                }
            } catch {
                DispatchQueue.main.async { self.isLoading = false }
            }
        }.resume()
    }

    // MARK: - Geocoding

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                self?.locationName = placemarks?.first?.locality ?? ""
            }
        }
    }

    // MARK: - Timer

    private func startRefreshTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            guard let self = self, let coord = self.lastCoordinate else { return }
            self.fetchWeather(lat: coord.latitude, lon: coord.longitude)
        }
    }

    // MARK: - API

    private func fetchWeather(lat: Double, lon: Double) {
        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(lat)&longitude=\(lon)"
            + "&current=temperature_2m,apparent_temperature,weather_code,relative_humidity_2m,wind_speed_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&timezone=auto&forecast_days=5"

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            do {
                let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                DispatchQueue.main.async {
                    self?.applyResponse(response)
                    self?.isLoading = false
                }
            } catch {
                DispatchQueue.main.async { self?.isLoading = false }
            }
        }.resume()
    }

    private func applyResponse(_ r: OpenMeteoResponse) {
        temperature = r.current.temperature_2m
        apparentTemperature = r.current.apparent_temperature
        weatherCode = r.current.weather_code
        humidity = r.current.relative_humidity_2m
        windSpeed = r.current.wind_speed_10m

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var days: [DayForecast] = []
        for i in 0..<min(r.daily.time.count, r.daily.weather_code.count) {
            let date = formatter.date(from: r.daily.time[i]) ?? Date()
            days.append(DayForecast(
                date: date,
                weatherCode: r.daily.weather_code[i],
                tempMax: r.daily.temperature_2m_max[i],
                tempMin: r.daily.temperature_2m_min[i]
            ))
        }
        forecast = days
    }

    // MARK: - Weather Code → SF Symbol

    static func sfSymbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "sun.min.fill"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77: return "snowflake"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm w/ hail"
        default: return "Unknown"
        }
    }
}

// MARK: - API Response Models

private struct OpenMeteoResponse: Decodable {
    let current: CurrentWeather
    let daily: DailyWeather
}

private struct CurrentWeather: Decodable {
    let temperature_2m: Double
    let apparent_temperature: Double
    let weather_code: Int
    let relative_humidity_2m: Int
    let wind_speed_10m: Double
}

private struct DailyWeather: Decodable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
}

private struct IPGeoResponse: Decodable {
    let latitude: Double
    let longitude: Double
    let city: String?
}
