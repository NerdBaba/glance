import SwiftUI

struct WeatherPopup: View {
    @ObservedObject var viewModel: WeatherViewModel
    @ObservedObject var configManager = ConfigManager.shared
    var appearance: AppearanceConfig { configManager.config.appearance }

    var body: some View {
        VStack(spacing: 14) {
            if let temp = viewModel.temperature {
                currentConditions(temp: temp)
            } else if viewModel.isLoading {
                loadingState
            } else {
                emptyState
            }

            if viewModel.temperature != nil {
                Divider().opacity(0.15)

                VStack(alignment: .leading, spacing: 5) {
                    if let feels = viewModel.apparentTemperature {
                        detailRow("Feels like", String(format: "%.0f°C", feels))
                    }
                    detailRow("Humidity", "\(viewModel.humidity)%")
                    detailRow("Wind", String(format: "%.0f km/h", viewModel.windSpeed))
                    detailRow("Source", viewModel.providerDisplayName)
                    if let updatedAt = viewModel.lastUpdatedAt {
                        detailRow("Updated", relativeTime(updatedAt))
                    }
                }
                .font(.system(size: 12))
                .opacity(0.7)
            }

            if !viewModel.forecast.isEmpty {
                Divider().opacity(0.15)

                VStack(spacing: 6) {
                    ForEach(viewModel.forecast) { day in
                        forecastRow(day)
                    }
                }
                .font(.system(size: 12))
            }

            if viewModel.isUsingApproximateLocation {
                Divider().opacity(0.15)
                Text("Approximate location via network")
                    .font(.system(size: 11))
                    .opacity(0.4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 200)
        .padding(22)
    }

    @ViewBuilder
    private func currentConditions(temp: Double) -> some View {
        VStack(spacing: 6) {
            Image(systemName: viewModel.currentCondition.symbolName)
                .font(.system(size: 32))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(appearance.accentColor)

            Text(String(format: "%.0f°C", temp))
                .font(.system(size: 24, weight: .semibold))
                .monospacedDigit()

            Text(viewModel.currentCondition.description)
                .font(.system(size: 12))
                .opacity(0.6)

            if !viewModel.locationName.isEmpty {
                Text(viewModel.locationName)
                    .font(.system(size: 11))
                    .opacity(0.4)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Loading weather…")
                .font(.system(size: 12))
                .opacity(0.5)
        }
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.slash")
                .font(.system(size: 24))
                .foregroundStyle(appearance.accentColor.opacity(0.7))
            Text("Weather unavailable")
                .font(.system(size: 13, weight: .semibold))
            if let message = viewModel.lastErrorMessage {
                Text(message)
                    .font(.system(size: 11))
                    .opacity(0.5)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
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

            Image(systemName: day.condition.symbolName)
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

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}
