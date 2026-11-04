import AppKit
import SwiftUI

/// Settings tab for wallpaper → bar generation: enter a TypeSafe/Jev API key,
/// configure the provider, and run a typed "tweak" generation. Deciding are
/// always previewed here — nothing is applied automatically.
struct WallpaperSettingsTab: View {

    @ObservedObject private var configManager = ConfigManager.shared
    private static let keyAccount = "typesafe-jev-key"

    @State private var apiKey = ""
    @State private var providerType = "typesafe-jev"
    @State private var model = "jev-latest"
    @State private var baseURL = ""
    @State private var autoGenerate = false
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var decisions: [BarTweakDecision] = []

    var body: some View {
        Form {
            Section {
                Text("Generate bar tweaks from the desktop wallpaper. Decisions are typed, confidence-scored, and always previewed here before you apply them.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Section("Provider") {
                Picker("Backend", selection: $providerType) {
                    Text("TypeSafe Jev (decision model)").tag("typesafe-jev")
                    Text("OpenAI-compatible (coming soon)").tag("openai-compatible").disabled(true)
                }
                SecureField("TypeSafe API key", text: $apiKey)
                    .textContentType(.password)
                TextField("Model", text: $model)
                TextField("Base URL (optional)", text: $baseURL)
                Text("Key is stored in the macOS Keychain, never in your config or logs.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Recolor bar from wallpaper", isOn: wallpaperPalette)
                Toggle("Auto-generate when wallpaper changes", isOn: $autoGenerate)
            }

            Section {
                Button(action: runGeneration) {
                    HStack {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(isLoading ? "Generating…" : "Generate tweaks")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isLoading)
            }

            if let errorText {
                Section {
                    Text(errorText).foregroundStyle(.red).font(.callout)
                }
            }

            if !decisions.isEmpty {
                Section("Decisions (confidence ≥ 60%)") {
                    ForEach(decisions) { decision in
                        HStack {
                            Text(decision.key)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(decision.value)
                            Text(String(format: "%.0f%%", decision.confidence * 100))
                                .foregroundStyle(.secondary).font(.caption)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: loadFromConfig)
    }

    // MARK: - Bindings

    private var wallpaperPalette: Binding<Bool> {
        Binding(
            get: { configManager.config.rootToml.experimental?.wallpaperPalette == true },
            set: { newValue in
                configManager.updateConfigValue(
                    key: "experimental.wallpaper-palette",
                    newValue: newValue ? "true" : "false")
            }
        )
    }

    // MARK: - Load / save

    private func loadFromConfig() {
        apiKey = KeychainStore.get(account: Self.keyAccount) ?? ""
        let wallpaper = configManager.config.rootToml.experimental?.wallpaper
        providerType = wallpaper?.provider?.type ?? "typesafe-jev"
        model = wallpaper?.provider?.model ?? "jev-latest"
        baseURL = wallpaper?.provider?.baseURL ?? ""
        autoGenerate = wallpaper?.autoGenerate ?? false
    }

    private func saveProviderConfig() {
        KeychainStore.set(apiKey, account: Self.keyAccount)
        configManager.updateConfigValues(pairs: [
            ("experimental.wallpaper.auto-generate", autoGenerate ? "true" : "false"),
            ("experimental.wallpaper.provider.type", providerType),
            ("experimental.wallpaper.provider.model", model),
            ("experimental.wallpaper.provider.base-url", baseURL),
        ])
    }

    // MARK: - Generation

    private func runGeneration() {
        saveProviderConfig()
        errorText = nil
        decisions = []
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let state = Self.buildState(manager: configManager)
                let key = KeychainStore.get(account: Self.keyAccount) ?? ""
                let provider = try TweakProviderFactory.make(
                    type: providerType,
                    baseURL: baseURL.isEmpty ? nil : baseURL,
                    model: model,
                    apiKey: key)
                let patch = try await provider.generateTweak(state: state)
                await MainActor.run {
                    decisions = patch.decisions
                    if patch.decisions.isEmpty {
                        errorText = "No decisions cleared the confidence threshold (60%). Try again, or pick a different model."
                    }
                }
            } catch {
                await MainActor.run { errorText = error.localizedDescription }
            }
        }
    }

    private static func buildState(manager: ConfigManager) -> BarTweakState {
        let config = manager.config
        let hexes = paletteHexes(from: manager)
        let widgets = config.rootToml.widgets?.displayed.map(\.id) ?? []
        let formation = config.experimental.foreground.formation.rawValue
        let template = config.rootToml.preset ?? "current"
        return BarTweakState(
            paletteHex: hexes,
            templateName: template,
            formation: formation,
            widgetIDs: widgets,
            intent: "")
    }

    private static func paletteHexes(from manager: ConfigManager) -> [String] {
        if let colors = manager.config.pywalColors?.colors, !colors.isEmpty {
            return colors.map { hex(NSColor($0)) }
        }
        if let url = WallpaperPalette.currentWallpaperURL(),
           let palette = WallpaperPalette.extract(from: url) {
            return palette.colors.map { hex(NSColor($0)) }
        }
        return []
    }

    private static func hex(_ color: NSColor) -> String {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int((srgb.redComponent * 255).rounded())
        let g = Int((srgb.greenComponent * 255).rounded())
        let b = Int((srgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
