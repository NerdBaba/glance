import Foundation
import Carbon.HIToolbox

final class InputLanguageViewModel: ObservableObject {
    @Published var languageCode: String = ""
    @Published var fullName: String = ""

    private var observer: NSObjectProtocol?

    init() {
        updateInputSource()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateInputSource()
        }
    }

    deinit {
        if let observer = observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    private func updateInputSource() {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }

        if let langsPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
            let cfArray = Unmanaged<CFArray>.fromOpaque(langsPtr).takeUnretainedValue()
            let languages = cfArray as [AnyObject]
            if let lang = languages.first as? String {
                languageCode = String(lang.prefix(2)).uppercased()
            }
        }

        if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
            fullName = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        }
    }
}
