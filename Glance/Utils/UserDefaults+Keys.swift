import Foundation

extension UserDefaults {
    static let randomazzoHotkeyKey = "randomazzoHotkey"
    static let randomazzoExcludeCurrentKey = "randomazzoExcludeCurrent"

    var randomazzoHotkey: String {
        get { string(forKey: UserDefaults.randomazzoHotkeyKey) ?? "ctrl+option+r" }
        set { set(newValue, forKey: UserDefaults.randomazzoHotkeyKey) }
    }

    var randomazzoExcludeCurrent: Bool {
        get { bool(forKey: UserDefaults.randomazzoExcludeCurrentKey) }
        set { set(newValue, forKey: UserDefaults.randomazzoExcludeCurrentKey) }
    }
}
