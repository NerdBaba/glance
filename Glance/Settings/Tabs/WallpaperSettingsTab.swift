import AppKit
import SwiftUI

/// Settings tab for wallpaper → bar generation: enter a provider API key,
/// configure the backend, run a typed "tweak" generation, preview the decisions,
/// and optionally apply them to the live config.
struct WallpaperSettingsTab: View {

    @ObservedObject private var configManager = ConfigManager.shared

    @State private var apiKey = ""
    @State private var providerType = "typesafe-jev"
    @State private var model = "jev-latest"
    @State private var baseURL = ""
    @State private var autoGenerate = false
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var statusText: String?
    @State private var decisions: [BarTweakDecision] = []
    @State private var variations: [BarVariationCandidate] = []
    @State private var generatingVariations = false

    private var keyAccount: String {
        providerType == "openai-compatible" ? "openai-key" : "typesafe-jev-key"
    }

    var body: some View {
        Form {
            Section {
                Text("Generate bar tweaks from the desktop wallpaper. Decisions are typed, confidence-scored, and always previewed here before you apply them.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Section("Provider") {
                Picker("Backend", selection: $providerType) {
                    Text("TypeSafe Jev (decision model)").tag("typesafe-jev")
                    Text("OpenAI-compatible").tag("openai-compatible")
                }
                SecureField("API key", text: $apiKey)
                    .textContentType(.password)
                TextField("Model", text: $model)
                TextField("Base URL (optional)", text: $baseURL)
                Text("\(providerType == "openai-compatible" ? "OpenAI" : "TypeSafe") key is stored in the macOS Keychain, never in your config or logs.")
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

                Button(action: generateVariations) {
                    HStack {
                        if generatingVariations {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "square.grid.2x2")
                        }
                        Text(generatingVariations ? "Rendering…" : "Next variation")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(generatingVariations || isLoading)

                Button(action: applyDecisions) {
                    Label("Apply decisions to config", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .disabled(decisions.isEmpty || isLoading)
            }

            if !variations.isEmpty {
                Section("Variations (headless previews)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(variations) { variation in
                                VStack(alignment: .leading, spacing: 6) {
                                    if let image = variation.image {
                                        Image(nsImage: image)
                                            .resizable()
                                            .interpolation(.high)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(height: 56)
                                            .frame(maxWidth: 460)
                                            .background(Color.black.opacity(0.5))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 320, height: 56)
                                    }
                                    Text(variation.title).font(.headline)
                                    Text(variation.subtitle).font(.caption).foregroundStyle(.secondary)
                                    Button("Apply", systemImage: "checkmark.circle") {
                                        applyVariation(variation)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(isLoading)
                                }
                                .frame(width: 320)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let errorText {
                Section {
                    Text(errorText).foregroundStyle(.red).font(.callout)
                }
            }
            if let statusText {
                Section {
                    Text(statusText).foregroundStyle(.green).font(.callout)
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
        apiKey = KeychainStore.get(account: keyAccount) ?? ""
        let wallpaper = configManager.config.rootToml.experimental?.wallpaper
        providerType = wallpaper?.provider?.type ?? "typesafe-jev"
        model = wallpaper?.provider?.model ?? "jev-latest"
        baseURL = wallpaper?.provider?.baseURL ?? ""
        autoGenerate = wallpaper?.autoGenerate ?? false
    }

    private func saveProviderConfig() {
        KeychainStore.set(apiKey, account: keyAccount)
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
        statusText = nil
        decisions = []
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let state = WallpaperThemeGenerator.buildTweakState(manager: configManager)
                let key = KeychainStore.get(account: keyAccount) ?? ""
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

    private func applyDecisions() {
        guard !decisions.isEmpty else { return }
        let patch = BarTweakPatch(decisions: decisions)
        if WallpaperTweakApplier.apply(patch: patch, to: configManager) {
            statusText = "Applied. The bar hot-reloads with the new configuration."
            decisions = []
        } else {
            errorText = "Nothing to apply — no decisions were within range."
        }
    }

    /// Render the four local composition variations as headless previews.
    private func generateVariations() {
        errorText = nil
        statusText = nil
        generatingVariations = true
        Task {
            let candidates = WallpaperVariation.generateCandidates(manager: configManager)
            await MainActor.run {
                generatingVariations = false
                variations = candidates
                if candidates.isEmpty { errorText = "Could not render variations — is there a config to base them on?" }
            }
        }
    }

    private func applyVariation(_ variation: BarVariationCandidate) {
        if WallpaperTweakApplier.apply(patch: variation.patch, to: configManager) {
            statusText = "Applied “\(variation.title)”. The bar hot-reloads."
        } else {
            errorText = "Could not apply that variation."
        }
    }
}
