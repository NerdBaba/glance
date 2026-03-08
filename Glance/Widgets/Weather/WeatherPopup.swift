import SwiftUI

struct WeatherPopup: View {
    @ObservedObject var viewModel: WeatherViewModel
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            // Current conditions
            if let temp = viewModel.temperature {
                VStack(spacing: 6) {
                    Image(systemName: WeatherViewModel.sfSymbol(for: viewModel.weatherCode))
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(appearance.accentColor)

                    Text(String(format: "%.0f°C", temp))
                        .font(.system(size: 24, weight: .semibold))
                        .monospacedDigit()

                    Text(WeatherViewModel.description(for: viewModel.weatherCode))
                        .font(.system(size: 12))
                        .opacity(0.6)

                    if !viewModel.locationName.isEmpty {
                        Text(viewModel.locationName)
                            .font(.system(size: 11))
                            .opacity(0.4)
                    }
                }
            }

            Divider().opacity(0.15)

            // Details
            VStack(alignment: .leading, spacing: 5) {
                if let feels = viewModel.apparentTemperature {
                    detailRow("Feels like", String(format: "%.0f°C", feels))
                }
                detailRow("Humidity", "\(viewModel.humidity)%")
                detailRow("Wind", String(format: "%.0f km/h", viewModel.windSpeed))
            }
            .font(.system(size: 12))
            .opacity(0.7)

            // 5-day forecast
            if !viewModel.forecast.isEmpty {
                Divider().opacity(0.15)

                VStack(spacing: 6) {
                    ForEach(viewModel.forecast) { day in
                        forecastRow(day)
                    }
                }
                .font(.system(size: 12))
            }
        }
        .frame(width: 180)
        .padding(22)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .opacity(0.5)
            Spacer()
            Text(value)
        }
    }

    @ViewBuilder
    private func forecastRow(_ day: WeatherViewModel.DayForecast) -> some View {
        HStack(spacing: 8) {
            Text(dayName(day.date))
                .frame(width: 36, alignment: .leading)
                .opacity(0.5)

            Image(systemName: WeatherViewModel.sfSymbol(for: day.weatherCode))
                .font(.system(size: 12))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 20)

            Spacer()

            Text(String(format: "%.0f°", day.tempMin))
                .opacity(0.4)
                .monospacedDigit()

            Text(String(format: "%.0f°", day.tempMax))
                .monospacedDigit()
        }
    }

    private func dayName(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
