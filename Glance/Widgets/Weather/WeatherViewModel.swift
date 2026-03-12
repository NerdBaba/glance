import AppKit
import CoreLocation
import Foundation

final class WeatherViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherViewModel()

    struct WeatherCondition: Equatable {
        let symbolName: String
        let description: String

        static let unknown = WeatherCondition(symbolName: "cloud.fill", description: "Unknown")
    }

    struct DayForecast: Identifiable {
        let id = UUID()
        let date: Date
        let condition: WeatherCondition
        let tempMax: Double
        let tempMin: Double
    }

    @Published var temperature: Double?
    @Published var apparentTemperature: Double?
    @Published var currentCondition: WeatherCondition = .unknown
    @Published var humidity: Int = 0
    @Published var windSpeed: Double = 0  // km/h
    @Published var forecast: [DayForecast] = []
    @Published var locationName: String = ""
    @Published var isLoading = true
    @Published var lastUpdatedAt: Date?
    @Published var lastErrorMessage: String?
    @Published var isUsingApproximateLocation = false
    @Published var providerDisplayName = "MET Norway"

    private enum WeatherProvider: String, Equatable {
        case metNo = "met-no"
        case openMeteo = "open-meteo"

        var displayName: String {
            switch self {
            case .metNo:
                return "MET Norway"
            case .openMeteo:
                return "Open-Meteo"
            }
        }
    }

    private struct ManualLocation: Equatable {
        let latitude: Double
        let longitude: Double
        let name: String?
    }

    private struct WeatherConfiguration: Equatable {
        var provider: WeatherProvider = .metNo
        var manualLocation: ManualLocation?
        var useIPFallback = true
    }

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let decoder = JSONDecoder()
    private let isoFormatter = ISO8601DateFormatter()

    private var timer: Timer?
    private var lastCoordinate: CLLocationCoordinate2D?
    private var didAttemptFallback = false
    private var ipFallbackTask: URLSessionDataTask?
    private var weatherTask: URLSessionDataTask?
    private var wakeObserver: NSObjectProtocol?
    private var locationTimeoutWorkItem: DispatchWorkItem?
    private var configuration = WeatherConfiguration()
    private let locationLookupTimeout: TimeInterval = 8

    private let logger = AppLogger.shared

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAfterWake()
        }

        resolveLocation()
    }

    deinit {
        timer?.invalidate()
        ipFallbackTask?.cancel()
        weatherTask?.cancel()
        locationTimeoutWorkItem?.cancel()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    func configure(from config: ConfigData) {
        let newConfiguration = configuration(from: config)
        guard newConfiguration != configuration else { return }

        configuration = newConfiguration
        providerDisplayName = newConfiguration.provider.displayName

        logger.info(
            "Weather configuration updated: provider=\(newConfiguration.provider.rawValue), manualLocation=\(newConfiguration.manualLocation != nil), ipFallback=\(newConfiguration.useIPFallback)",
            category: .weather
        )

        applyConfiguration()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if isAuthorized(status) {
            lastErrorMessage = nil
            isUsingApproximateLocation = false
            scheduleLocationTimeout()
            manager.startUpdatingLocation()
        } else if status == .denied || status == .restricted {
            cancelLocationTimeout()
            if configuration.useIPFallback && !didAttemptFallback {
                fallbackToPrimaryIPGeolocation()
            } else if !configuration.useIPFallback {
                clearWeather(reason: "Grant Location access or set weather coordinates in config for accurate weather.")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        cancelLocationTimeout()
        locationManager.stopUpdatingLocation()
        lastCoordinate = location.coordinate
        lastErrorMessage = nil
        isUsingApproximateLocation = false

        reverseGeocode(location)
        fetchWeather(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        startRefreshTimer()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.warning("Location update failed: \(error.localizedDescription)", category: .weather)

        if let clError = error as? CLError, clError.code == .locationUnknown {
            return
        }

        cancelLocationTimeout()
        if configuration.useIPFallback && !didAttemptFallback {
            fallbackToPrimaryIPGeolocation()
        } else if !configuration.useIPFallback {
            clearWeather(reason: "Weather needs Location access or manual coordinates in config.")
        }
    }

    // MARK: - Configuration

    private func applyConfiguration() {
        weatherTask?.cancel()
        ipFallbackTask?.cancel()
        geocoder.cancelGeocode()
        timer?.invalidate()
        cancelLocationTimeout()

        if let manualLocation = configuration.manualLocation {
            didAttemptFallback = false
            isUsingApproximateLocation = false
            lastCoordinate = CLLocationCoordinate2D(
                latitude: manualLocation.latitude,
                longitude: manualLocation.longitude
            )
            locationName = manualLocation.name ?? ""
            lastErrorMessage = nil

            if manualLocation.name == nil {
                reverseGeocode(
                    CLLocation(latitude: manualLocation.latitude, longitude: manualLocation.longitude)
                )
            }

            fetchWeather(lat: manualLocation.latitude, lon: manualLocation.longitude)
            startRefreshTimer()
        } else {
            resolveLocation()
        }
    }

    private func configuration(from config: ConfigData) -> WeatherConfiguration {
        let provider = WeatherProvider(rawValue: config["provider"]?.stringValue ?? "") ?? .metNo
        let useIPFallback = config["use-ip-fallback"]?.boolValue ?? true
        let locationConfig = config["location"]?.dictionaryValue ?? [:]

        let latitude = locationConfig["latitude"]?.doubleValue ?? config["latitude"]?.doubleValue
        let longitude = locationConfig["longitude"]?.doubleValue ?? config["longitude"]?.doubleValue
        let name = locationConfig["name"]?.stringValue ?? config["location-name"]?.stringValue

        let manualLocation: ManualLocation?
        if let latitude, let longitude {
            manualLocation = ManualLocation(latitude: latitude, longitude: longitude, name: name)
        } else {
            manualLocation = nil
        }

        return WeatherConfiguration(
            provider: provider,
            manualLocation: manualLocation,
            useIPFallback: useIPFallback
        )
    }

    // MARK: - Location Resolution

    private func resolveLocation() {
        let status = locationManager.authorizationStatus

        if status == .notDetermined {
            isLoading = temperature == nil
            scheduleLocationTimeout()
            locationManager.startUpdatingLocation()
            return
        }

        if isAuthorized(status) {
            isLoading = temperature == nil
            scheduleLocationTimeout()
            locationManager.startUpdatingLocation()
            return
        }

        if status == .denied || status == .restricted {
            cancelLocationTimeout()
            if configuration.useIPFallback {
                fallbackToPrimaryIPGeolocation()
            } else {
                clearWeather(reason: "Grant Location access or set weather coordinates in config for accurate weather.")
            }
            return
        }

        clearWeather(reason: "Weather location access is unavailable.")
    }

    private func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorized || status == .authorizedAlways
    }

    private func scheduleLocationTimeout() {
        locationTimeoutWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.locationTimeoutWorkItem = nil

            guard self.configuration.manualLocation == nil else { return }
            guard self.temperature == nil || self.lastCoordinate == nil else { return }

            self.logger.warning(
                "Location lookup timed out after \(Int(self.locationLookupTimeout))s; falling back to network location if allowed",
                category: .weather
            )

            DispatchQueue.main.async {
                self.locationManager.stopUpdatingLocation()
                if self.configuration.useIPFallback && !self.didAttemptFallback {
                    self.fallbackToPrimaryIPGeolocation()
                } else if !self.configuration.useIPFallback {
                    self.clearWeather(reason: "Weather needs Location access or manual coordinates in config.")
                }
            }
        }

        locationTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + locationLookupTimeout, execute: workItem)
    }

    private func cancelLocationTimeout() {
        locationTimeoutWorkItem?.cancel()
        locationTimeoutWorkItem = nil
    }

    // MARK: - IP Fallback

    private func fallbackToPrimaryIPGeolocation() {
        didAttemptFallback = true
        cancelLocationTimeout()
        logger.info("Falling back to primary IP geolocation", category: .weather)

        guard let url = URL(string: "https://ipapi.co/json/") else {
            clearWeather(reason: "Location lookup unavailable.")
            return
        }

        ipFallbackTask?.cancel()
        ipFallbackTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }

            guard let data, error == nil else {
                self.fallbackToSecondaryIPGeolocation(reason: error?.localizedDescription ?? "unknown error")
                return
            }

            do {
                let geo = try self.decoder.decode(IPGeoResponse.self, from: data)
                guard let latitude = geo.latitude, let longitude = geo.longitude else {
                    self.fallbackToSecondaryIPGeolocation(reason: "primary IP geolocation returned empty coordinates")
                    return
                }

                DispatchQueue.main.async {
                    self.lastCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    self.locationName = geo.city ?? ""
                    self.isUsingApproximateLocation = true
                    self.lastErrorMessage = nil
                    if self.locationName.isEmpty {
                        self.reverseGeocode(CLLocation(latitude: latitude, longitude: longitude))
                    }
                    self.fetchWeather(lat: latitude, lon: longitude)
                    self.startRefreshTimer()
                }
            } catch {
                self.fallbackToSecondaryIPGeolocation(
                    reason: "failed to decode primary IP geolocation: \(error.localizedDescription)"
                )
            }
        }
        ipFallbackTask?.resume()
    }

    private func fallbackToSecondaryIPGeolocation(reason: String) {
        logger.warning("Primary IP geolocation failed: \(reason)", category: .weather)
        logger.info("Falling back to secondary IP geolocation", category: .weather)

        guard let url = URL(string: "https://ipwho.is/") else {
            DispatchQueue.main.async {
                self.clearWeather(reason: "Weather needs Location access or manual coordinates in config.")
            }
            return
        }

        ipFallbackTask?.cancel()
        ipFallbackTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }

            guard let data, error == nil else {
                DispatchQueue.main.async {
                    self.logger.warning(
                        "Secondary IP geolocation failed: \(error?.localizedDescription ?? "unknown error")",
                        category: .weather
                    )
                    self.clearWeather(reason: "Weather needs Location access or manual coordinates in config.")
                }
                return
            }

            do {
                let geo = try self.decoder.decode(IPWhoResponse.self, from: data)
                guard geo.success, let latitude = geo.latitude, let longitude = geo.longitude else {
                    DispatchQueue.main.async {
                        self.clearWeather(reason: "Weather needs Location access or manual coordinates in config.")
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.lastCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    self.locationName = geo.city ?? ""
                    self.isUsingApproximateLocation = true
                    self.lastErrorMessage = nil
                    if self.locationName.isEmpty {
                        self.reverseGeocode(CLLocation(latitude: latitude, longitude: longitude))
                    }
                    self.fetchWeather(lat: latitude, lon: longitude)
                    self.startRefreshTimer()
                }
            } catch {
                DispatchQueue.main.async {
                    self.logger.warning(
                        "Failed to decode secondary IP geolocation response: \(error.localizedDescription)",
                        category: .weather
                    )
                    self.clearWeather(reason: "Weather needs Location access or manual coordinates in config.")
                }
            }
        }
        ipFallbackTask?.resume()
    }

    // MARK: - Geocoding

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                self?.locationName = placemarks?.first?.locality ?? self?.locationName ?? ""
            }
        }
    }

    // MARK: - Refresh

    private func startRefreshTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            guard let self else { return }

            if let manualLocation = self.configuration.manualLocation {
                self.fetchWeather(lat: manualLocation.latitude, lon: manualLocation.longitude)
            } else if let coord = self.lastCoordinate {
                self.fetchWeather(lat: coord.latitude, lon: coord.longitude)
            }
        }
        timer?.tolerance = 60
    }

    private func refreshAfterWake() {
        if let manualLocation = configuration.manualLocation {
            fetchWeather(lat: manualLocation.latitude, lon: manualLocation.longitude)
        } else if let coord = lastCoordinate {
            fetchWeather(lat: coord.latitude, lon: coord.longitude)
        } else {
            resolveLocation()
        }
    }

    private func clearWeather(reason: String) {
        cancelLocationTimeout()
        temperature = nil
        apparentTemperature = nil
        currentCondition = .unknown
        humidity = 0
        windSpeed = 0
        forecast = []
        isLoading = false
        lastErrorMessage = reason
    }

    // MARK: - Weather Fetch

    private func fetchWeather(lat: Double, lon: Double) {
        switch configuration.provider {
        case .metNo:
            fetchMetNoWeather(lat: lat, lon: lon)
        case .openMeteo:
            fetchOpenMeteoWeather(lat: lat, lon: lon)
        }
    }

    private func fetchOpenMeteoWeather(lat: Double, lon: Double) {
        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(lat)&longitude=\(lon)"
            + "&current=temperature_2m,apparent_temperature,weather_code,relative_humidity_2m,wind_speed_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&timezone=auto&forecast_days=5"

        guard let url = URL(string: urlString) else { return }

        performWeatherRequest(
            urlRequest: URLRequest(url: url),
            providerName: WeatherProvider.openMeteo.displayName
        ) { [weak self] data in
            guard let self else { return }
            let response = try self.decoder.decode(OpenMeteoResponse.self, from: data)

            DispatchQueue.main.async {
                self.applyOpenMeteoResponse(response)
                self.providerDisplayName = WeatherProvider.openMeteo.displayName
                self.lastUpdatedAt = Date()
                self.lastErrorMessage = nil
                self.isLoading = false
                self.logger.info(
                    "Weather updated from \(WeatherProvider.openMeteo.displayName); approximateLocation=\(self.isUsingApproximateLocation)",
                    category: .weather
                )
            }
        }
    }

    private func fetchMetNoWeather(lat: Double, lon: Double) {
        guard let url = URL(
            string: "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=\(lat)&lon=\(lon)"
        ) else { return }

        var request = URLRequest(url: url)
        request.setValue(
            "Glance/\(VersionChecker.currentVersion ?? "dev") (https://github.com/azixxxxx/glance)",
            forHTTPHeaderField: "User-Agent"
        )

        performWeatherRequest(urlRequest: request, providerName: WeatherProvider.metNo.displayName) { [weak self] data in
            guard let self else { return }
            let response = try self.decoder.decode(MetNoResponse.self, from: data)

            DispatchQueue.main.async {
                self.applyMetNoResponse(response)
                self.providerDisplayName = WeatherProvider.metNo.displayName
                self.lastUpdatedAt = Date()
                self.lastErrorMessage = nil
                self.isLoading = false
                self.logger.info(
                    "Weather updated from \(WeatherProvider.metNo.displayName); approximateLocation=\(self.isUsingApproximateLocation)",
                    category: .weather
                )
            }
        }
    }

    private func performWeatherRequest(
        urlRequest: URLRequest,
        providerName: String,
        decodeAndApply: @escaping (Data) throws -> Void
    ) {
        if temperature == nil {
            isLoading = true
        }

        weatherTask?.cancel()
        weatherTask = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, _, error in
            guard let self else { return }

            guard let data, error == nil else {
                DispatchQueue.main.async {
                    self.logger.warning(
                        "\(providerName) request failed: \(error?.localizedDescription ?? "unknown error")",
                        category: .weather
                    )
                    self.isLoading = false
                    self.lastErrorMessage = "Weather is unavailable right now."
                }
                return
            }

            do {
                try decodeAndApply(data)
            } catch {
                DispatchQueue.main.async {
                    self.logger.warning(
                        "\(providerName) decode failed: \(error.localizedDescription)",
                        category: .weather
                    )
                    self.isLoading = false
                    self.lastErrorMessage = "Weather data could not be parsed."
                }
            }
        }
        weatherTask?.resume()
    }

    // MARK: - Apply Provider Responses

    private func applyOpenMeteoResponse(_ response: OpenMeteoResponse) {
        temperature = response.current.temperature_2m
        apparentTemperature = response.current.apparent_temperature
        currentCondition = Self.condition(forWMO: response.current.weather_code)
        humidity = response.current.relative_humidity_2m
        windSpeed = response.current.wind_speed_10m

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let forecastCount = min(
            response.daily.time.count,
            response.daily.weather_code.count,
            response.daily.temperature_2m_max.count,
            response.daily.temperature_2m_min.count
        )

        forecast = (0..<forecastCount).map { index in
            DayForecast(
                date: formatter.date(from: response.daily.time[index]) ?? Date(),
                condition: Self.condition(forWMO: response.daily.weather_code[index]),
                tempMax: response.daily.temperature_2m_max[index],
                tempMin: response.daily.temperature_2m_min[index]
            )
        }
    }

    private func applyMetNoResponse(_ response: MetNoResponse) {
        let resolvedSeries = response.properties.timeseries.compactMap { entry -> ResolvedMetEntry? in
            guard let date = isoFormatter.date(from: entry.time) else { return nil }
            return ResolvedMetEntry(date: date, entry: entry)
        }

        guard let current = resolvedSeries.first else {
            clearWeather(reason: "Weather data was empty.")
            return
        }

        temperature = current.entry.data.instant.details.air_temperature
        apparentTemperature = nil
        humidity = Int(round(current.entry.data.instant.details.relative_humidity))
        windSpeed = current.entry.data.instant.details.wind_speed * 3.6
        currentCondition = Self.condition(forMetSymbol: resolvedMetSymbol(from: current.entry))
        forecast = buildMetForecast(from: resolvedSeries)
    }

    private func buildMetForecast(from resolvedSeries: [ResolvedMetEntry]) -> [DayForecast] {
        let calendar = Calendar.autoupdatingCurrent
        let grouped = Dictionary(grouping: resolvedSeries) { calendar.startOfDay(for: $0.date) }

        return grouped.keys.sorted().prefix(5).compactMap { day in
            guard let entries = grouped[day], !entries.isEmpty else { return nil }

            let targetHour = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
            let representative = entries.min {
                abs($0.date.timeIntervalSince(targetHour)) < abs($1.date.timeIntervalSince(targetHour))
            } ?? entries[0]

            let temperatures = entries.map { $0.entry.data.instant.details.air_temperature }
            guard let minTemp = temperatures.min(), let maxTemp = temperatures.max() else { return nil }

            return DayForecast(
                date: day,
                condition: Self.condition(forMetSymbol: resolvedMetSymbol(from: representative.entry)),
                tempMax: maxTemp,
                tempMin: minTemp
            )
        }
    }

    private func resolvedMetSymbol(from entry: MetNoTimeSeries) -> String {
        if let symbol = entry.data.next_1_hours?.summary.symbol_code {
            return symbol
        }
        if let symbol = entry.data.next_6_hours?.summary.symbol_code {
            return symbol
        }
        if let symbol = entry.data.next_12_hours?.summary.symbol_code {
            return symbol
        }

        let cloudArea = entry.data.instant.details.cloud_area_fraction
        if cloudArea < 15 { return "clearsky_day" }
        if cloudArea < 55 { return "partlycloudy_day" }
        return "cloudy"
    }

    // MARK: - Condition Mapping

    static func condition(forWMO code: Int) -> WeatherCondition {
        switch code {
        case 0:
            return WeatherCondition(symbolName: "sun.max.fill", description: "Clear sky")
        case 1:
            return WeatherCondition(symbolName: "sun.min.fill", description: "Mainly clear")
        case 2:
            return WeatherCondition(symbolName: "cloud.sun.fill", description: "Partly cloudy")
        case 3:
            return WeatherCondition(symbolName: "cloud.fill", description: "Overcast")
        case 45, 48:
            return WeatherCondition(symbolName: "cloud.fog.fill", description: "Fog")
        case 51, 53, 55:
            return WeatherCondition(symbolName: "cloud.drizzle.fill", description: "Drizzle")
        case 56, 57:
            return WeatherCondition(symbolName: "cloud.sleet.fill", description: "Freezing drizzle")
        case 61, 63, 65:
            return WeatherCondition(symbolName: "cloud.rain.fill", description: "Rain")
        case 66, 67:
            return WeatherCondition(symbolName: "cloud.sleet.fill", description: "Freezing rain")
        case 71, 73, 75:
            return WeatherCondition(symbolName: "cloud.snow.fill", description: "Snow")
        case 77:
            return WeatherCondition(symbolName: "snowflake", description: "Snow grains")
        case 80, 81, 82:
            return WeatherCondition(symbolName: "cloud.heavyrain.fill", description: "Rain showers")
        case 85, 86:
            return WeatherCondition(symbolName: "cloud.snow.fill", description: "Snow showers")
        case 95:
            return WeatherCondition(symbolName: "cloud.bolt.fill", description: "Thunderstorm")
        case 96, 99:
            return WeatherCondition(symbolName: "cloud.bolt.rain.fill", description: "Thunderstorm with hail")
        default:
            return .unknown
        }
    }

    static func condition(forMetSymbol symbolCode: String) -> WeatherCondition {
        let isNight = symbolCode.contains("_night")
        let normalized = symbolCode
            .replacingOccurrences(of: "_day", with: "")
            .replacingOccurrences(of: "_night", with: "")
            .replacingOccurrences(of: "_polartwilight", with: "")

        switch normalized {
        case "clearsky":
            return WeatherCondition(
                symbolName: isNight ? "moon.stars.fill" : "sun.max.fill",
                description: "Clear sky"
            )
        case "fair":
            return WeatherCondition(
                symbolName: isNight ? "moon.stars.fill" : "sun.min.fill",
                description: "Fair"
            )
        case "partlycloudy":
            return WeatherCondition(
                symbolName: isNight ? "cloud.moon.fill" : "cloud.sun.fill",
                description: "Partly cloudy"
            )
        case "cloudy":
            return WeatherCondition(symbolName: "cloud.fill", description: "Cloudy")
        case "fog":
            return WeatherCondition(symbolName: "cloud.fog.fill", description: "Fog")
        case "lightrainshowers", "rainshowers":
            return WeatherCondition(symbolName: "cloud.sun.rain.fill", description: "Rain showers")
        case "heavyrainshowers":
            return WeatherCondition(symbolName: "cloud.heavyrain.fill", description: "Heavy rain showers")
        case "lightsleetshowers", "sleetshowers":
            return WeatherCondition(symbolName: "cloud.sleet.fill", description: "Sleet showers")
        case "lightssnowshowers", "snowshowers":
            return WeatherCondition(symbolName: "cloud.snow.fill", description: "Snow showers")
        case "lightrain", "rain":
            return WeatherCondition(symbolName: "cloud.rain.fill", description: "Rain")
        case "heavyrain":
            return WeatherCondition(symbolName: "cloud.heavyrain.fill", description: "Heavy rain")
        case "lightsleet", "sleet":
            return WeatherCondition(symbolName: "cloud.sleet.fill", description: "Sleet")
        case "lightsnow", "snow":
            return WeatherCondition(symbolName: "cloud.snow.fill", description: "Snow")
        case "heavysnow":
            return WeatherCondition(symbolName: "snowflake", description: "Heavy snow")
        case "thunderstorm", "rainandthunder", "heavyrainandthunder":
            return WeatherCondition(symbolName: "cloud.bolt.rain.fill", description: "Thunderstorm")
        default:
            if normalized.contains("thunder") {
                return WeatherCondition(symbolName: "cloud.bolt.rain.fill", description: "Thunderstorm")
            }
            if normalized.contains("snow") {
                return WeatherCondition(symbolName: "cloud.snow.fill", description: "Snow")
            }
            if normalized.contains("sleet") {
                return WeatherCondition(symbolName: "cloud.sleet.fill", description: "Sleet")
            }
            if normalized.contains("drizzle") {
                return WeatherCondition(symbolName: "cloud.drizzle.fill", description: "Drizzle")
            }
            if normalized.contains("rain") {
                return WeatherCondition(symbolName: "cloud.rain.fill", description: "Rain")
            }
            return .unknown
        }
    }
}

// MARK: - Provider Models

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
    let latitude: Double?
    let longitude: Double?
    let city: String?
}

private struct IPWhoResponse: Decodable {
    let success: Bool
    let latitude: Double?
    let longitude: Double?
    let city: String?
}

private struct MetNoResponse: Decodable {
    let properties: MetNoProperties
}

private struct MetNoProperties: Decodable {
    let timeseries: [MetNoTimeSeries]
}

private struct MetNoTimeSeries: Decodable {
    let time: String
    let data: MetNoDataBlock
}

private struct MetNoDataBlock: Decodable {
    let instant: MetNoInstantBlock
    let next_1_hours: MetNoSummaryBlock?
    let next_6_hours: MetNoSummaryBlock?
    let next_12_hours: MetNoSummaryBlock?
}

private struct MetNoInstantBlock: Decodable {
    let details: MetNoInstantDetails
}

private struct MetNoInstantDetails: Decodable {
    let air_temperature: Double
    let cloud_area_fraction: Double
    let relative_humidity: Double
    let wind_speed: Double
}

private struct MetNoSummaryBlock: Decodable {
    let summary: MetNoSymbolSummary
}

private struct MetNoSymbolSummary: Decodable {
    let symbol_code: String
}

private struct ResolvedMetEntry {
    let date: Date
    let entry: MetNoTimeSeries
}
