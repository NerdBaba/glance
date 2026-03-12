import Foundation

final class AppUpdater: ObservableObject {
    @Published var latestVersion: String?
    @Published var updateAvailable = false

    private var updateTimer: Timer?
    private let logger = AppLogger.shared

    /// GitHub releases page — opened when user clicks "Update".
    static let releasesURL = URL(string: "https://github.com/azixxxxx/glance/releases/latest")!

    init() {
        fetchLatestRelease()
        // Check for updates every 30 minutes
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: 1800, repeats: true
        ) { [weak self] _ in
            self?.fetchLatestRelease()
        }
    }

    deinit {
        updateTimer?.invalidate()
    }

    func fetchLatestRelease() {
        guard
            let url = URL(
                string:
                    "https://api.github.com/repos/azixxxxx/glance/releases/latest"
            )
        else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error {
                self?.logger.warning("Error fetching release info: \(error.localizedDescription)", category: .updates)
                return
            }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                let tag = json["tag_name"] as? String
            else {
                self?.logger.warning("Release response did not contain a tag_name", category: .updates)
                return
            }

            let currentVersion = VersionChecker.currentVersion ?? "0.0.0"
            let comparisonResult =
                self?.compareVersion(tag, currentVersion) ?? 0
            DispatchQueue.main.async {
                self?.latestVersion = tag
                self?.updateAvailable = comparisonResult > 0
            }
        }.resume()
    }

    func compareVersion(_ v1: String, _ v2: String) -> Int {
        let version1 = v1.replacingOccurrences(of: "v", with: "")
        let version2 = v2.replacingOccurrences(of: "v", with: "")
        let parts1 = version1.split(separator: ".").compactMap { Int($0) }
        let parts2 = version2.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(parts1.count, parts2.count)
        for i in 0..<maxCount {
            let num1 = i < parts1.count ? parts1[i] : 0
            let num2 = i < parts2.count ? parts2[i] : 0
            if num1 > num2 { return 1 }
            if num1 < num2 { return -1 }
        }
        return 0
    }
}
