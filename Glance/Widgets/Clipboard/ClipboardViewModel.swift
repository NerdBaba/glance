import AppKit
import Foundation

struct ClipboardEntry: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
}

final class ClipboardViewModel: ObservableObject {
    static let shared = ClipboardViewModel()

    @Published var entries: [ClipboardEntry] = []

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var maxEntries = 20

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        timer?.tolerance = 0.25
    }

    deinit {
        timer?.invalidate()
    }

    func configure(from config: [String: TOMLValue]) {
        if let max = config["max-entries"]?.intValue {
            maxEntries = max
        }
    }

    private func checkClipboard() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        DispatchQueue.main.async {
            if self.entries.first?.text == text { return }
            self.entries.insert(ClipboardEntry(text: text, timestamp: Date()), at: 0)
            if self.entries.count > self.maxEntries {
                self.entries.removeLast()
            }
        }
    }

    func restore(_ entry: ClipboardEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
    }

    func clear() {
        entries.removeAll()
    }

    var entryCount: Int { entries.count }
}
