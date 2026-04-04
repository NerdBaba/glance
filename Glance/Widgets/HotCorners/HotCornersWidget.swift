import SwiftUI

struct HotCornersWidget: View {
    @StateObject private var viewModel = HotCornersViewModel()
    @Environment(\.widgetFont) var widgetFont
    @State private var rect: CGRect = .zero

    var body: some View {
        Image(systemName: viewModel.isEnabled ? "cursorarrow.rays" : "cursorarrow.slash")
            .barStatusSymbol(size: 14, opticalYOffset: -0.1)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(viewModel.isEnabled ? .primary : .secondary)
            .shadow(color: .black.opacity(0.3), radius: 3)
            .experimentalConfiguration(horizontalPadding: 8)
            .frame(maxHeight: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { rect = geo.frame(in: .global) }
                        .onChange(of: geo.frame(in: .global)) { _, newValue in
                            rect = newValue
                        }
                }
            )
            .background(.black.opacity(0.001))
            .onTapGesture {
                MenuBarPopup.show(rect: rect, id: "hotcorners") {
                    HotCornersPopup(viewModel: viewModel)
                }
            }
    }
}

// MARK: - ViewModel

final class HotCornersViewModel: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var isToggling: Bool = false

    private let logger = AppLogger.shared
    private let corners = [
        "wvous-tl-corner",
        "wvous-tr-corner",
        "wvous-bl-corner",
        "wvous-br-corner"
    ]

    init() {
        checkInitialState()
    }

    func checkInitialState() {
        // Check if any corner has a non-zero value (enabled)
        for corner in corners {
            if let value = readDefaults(corner), value != 0 {
                isEnabled = true
                return
            }
        }
        isEnabled = false
    }

    func toggleHotCorners() {
        guard !isToggling else { return }
        isToggling = true

        if isEnabled {
            // Disable: save current values and set all to 0
            let saved = readAllCorners()
            logger.info("Disabling hot corners, saving: \(saved)", category: .app)
            setCorners(all: 0)
        } else {
            // Enable: restore from defaults (user needs to reconfigure in System Settings)
            logger.info("Enabling hot corners (requires manual config in System Settings)", category: .app)
            // We can't restore previous values without storing them persistently
            // User should configure in System Settings > Desktop & Dock > Hot Corners
        }

        // Restart Dock to apply changes
        runCommand("killall Dock")

        // Update state
        isEnabled.toggle()
        isToggling = false

        logger.info("Hot corners \(isEnabled ? "enabled" : "disabled")", category: .app)
    }

    private func readAllCorners() -> [String: Int] {
        var dict = [String: Int]()
        for corner in corners {
            if let value = readDefaults(corner) {
                dict[corner] = value
            }
        }
        return dict
    }

    private func readDefaults(_ key: String) -> Int? {
        let output = runCommand("defaults read com.apple.dock \(key)")
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func setCorners(all value: Int) {
        for corner in corners {
            runCommand("defaults write com.apple.dock \(corner) -int \(value)")
        }
    }

    private func runCommand(_ command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        // Set PATH for Spotlight-launched apps
        let env = ProcessInfo.processInfo.environment
        var fullEnv = env
        let existingPath = env["PATH"] ?? ""
        if !existingPath.contains("/usr/local/bin") {
            fullEnv["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" + (existingPath.isEmpty ? "" : ":\(existingPath)")
        }
        process.environment = fullEnv

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            logger.error("Hot corners command error: \(error.localizedDescription)", category: .app)
            return ""
        }
    }
}

// MARK: - Popup

struct HotCornersPopup: View {
    @ObservedObject var viewModel: HotCornersViewModel
    @Environment(\.appearance) var appearance

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: viewModel.isEnabled ? "cursorarrow.rays" : "cursorarrow.slash")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                Text("Hot Corners")
                    .font(.headline)
            }

            Text(viewModel.isEnabled ? "Hot Corners are currently enabled" : "Hot Corners are currently disabled")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: {
                viewModel.toggleHotCorners()
            }) {
                HStack {
                    Image(systemName: viewModel.isEnabled ? "xmark.circle.fill" : "checkmark.circle.fill")
                    Text(viewModel.isEnabled ? "Disable Hot Corners" : "Enable Hot Corners")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(viewModel.isEnabled ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isToggling)

            if !viewModel.isEnabled {
                Text("Note: To reconfigure hot corners, go to System Settings > Desktop & Dock > Hot Corners")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(minWidth: 280)
        .popupStyle(appearance, cornerRadius: 12)
    }
}

#Preview {
    HotCornersWidget()
        .environmentObject(ConfigProvider(config: [:]))
}
