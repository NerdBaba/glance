import MarkdownUI
import SwiftUI

struct ChangelogPopup: View {
    @State private var changelogText: String = "Loading..."

    private var bundleVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0.0.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("v\(bundleVersion) Changelog")
                .padding(15)
                .font(.system(size: 14))
                .fontWeight(.medium)
            Rectangle().fill(.white).opacity(0.2).frame(height: 0.5)
            ScrollView {
                Markdown(changelogText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 20)
                    .padding(.trailing, 15)
                    .markdownTheme(.glance)
                    .foregroundStyle(.white)
            }.offset(x: 15)
                .markdownImageProvider(WebImageProvider())
        }
        .scrollIndicators(.hidden)
        .frame(width: 500)
        .frame(maxHeight: 600)
        .task {
            await loadChangelog()
        }
    }

    private func loadChangelog() async {
        // Try remote first, fall back to local bundled CHANGELOG.md
        if let remote = await fetchRemoteChangelog() {
            let section = extractSection(forVersion: bundleVersion, from: remote)
            if !section.isEmpty {
                updateChangelogText(section)
                return
            }
        }

        // Fallback: read from app bundle or project root
        if let local = loadLocalChangelog() {
            let section = extractSection(forVersion: bundleVersion, from: local)
            if !section.isEmpty {
                updateChangelogText(section)
                return
            }
        }

        updateChangelogText("Changelog for v\(bundleVersion) not found")
    }

    private func fetchRemoteChangelog() async -> String? {
        guard let url = URL(string: "https://raw.githubusercontent.com/azixxxxx/glance/main/CHANGELOG.md") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func loadLocalChangelog() -> String? {
        // Try bundle resource first
        if let bundleURL = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
           let content = try? String(contentsOf: bundleURL) {
            return content
        }
        // Try project root relative to executable
        let execURL = Bundle.main.bundleURL
            .deletingLastPathComponent()  // MacOS/
            .deletingLastPathComponent()  // Contents/
            .deletingLastPathComponent()  // Glance.app/
        let rootChangelog = execURL.appendingPathComponent("CHANGELOG.md")
        return try? String(contentsOf: rootChangelog)
    }

    // Updates the changelog text on the main thread
    private func updateChangelogText(_ text: String) {
        DispatchQueue.main.async {
            self.changelogText = text
        }
    }

    // Extracts the section corresponding to the specified version from the changelog
    private func extractSection(
        forVersion version: String, from changelog: String
    ) -> String {
        let lines = changelog.components(separatedBy: .newlines)

        guard
            let versionIndex = lines.firstIndex(where: {
                $0.contains("## \(version)")
            })
        else {
            return ""
        }

        var sectionLines: [String] = []
        for i in versionIndex..<lines.count {
            let line = lines[i]

            if i == versionIndex, line.hasPrefix("## ") {
                continue
            }

            // End the section when a new version header is encountered
            if i != versionIndex && line.hasPrefix("## ") {
                break
            }

            // Replace "<br>" with a markdown header if encountered
            if line == "<br>" {
                sectionLines.append("### ")
            } else {
                sectionLines.append(line)
            }
        }

        return sectionLines.joined(separator: "\n")
    }
}

// MARK: - Preview

struct ChangelogPopup_Previews: PreviewProvider {
    static var previews: some View {
        ChangelogPopup()
            .background(Color.black)
            .previewLayout(.sizeThatFits)
    }
}
