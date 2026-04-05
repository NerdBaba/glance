import Foundation

/// Maps application names to SF Symbol names for consistent icon rendering
enum IconStyle: String, Decodable {
    case appIcon      // Original NSApp icons
    case sfSymbol    // SF Symbols (monochromatic)
}

struct AppIconMapper {
    /// Comprehensive mapping of app names to SF Symbols
    private static let symbolMappings: [String: String] = [
        // Browsers
        "Safari": "safari",
        "Chrome": "globe",
        "Google Chrome": "globe",
        "Firefox": "firefox",
        "Arc": "globe",
        "Brave": "shield",
        "Edge": "microsoft.edge",
        "Opera": "opera",
        "Vivaldi": "globe",

        // Development
        "Xcode": "xcode",
        "Code": "chevron.left.forwardslash.chevron.right",
        "Visual Studio Code": "chevron.left.forwardslash.chevron.right",
        "VSCode": "chevron.left.forwardslash.chevron.right",
        "Sublime Text": "doc.text",
        "iTerm2": "terminal",
        "Terminal": "terminal",
        "Warp": "terminal",
        "Ghostty": "terminal",
        "Alacritty": "terminal",
        "Android Studio": "android",
        "IntelliJ IDEA": "keyboard",
        "PyCharm": "python",
        "WebStorm": "keyboard",
        "CLion": "keyboard",
        "Rider": "keyboard",
        "PhpStorm": "keyboard",
        "RubyMine": "keyboard",
        "AppCode": "keyboard",
        "DataGrip": "database",
        "GoLand": "keyboard",
        "Nova": "keyboard",
        "BBEdit": "doc.text",
        "TextMate": "doc.text",
        "MacVim": "doc.text",
        "Docker": "docker",
        "Docker Desktop": "docker",
        "Simulator": "iphone",
        "Android Emulator": "android",

        // Communication
        "Slack": "slack",
        "Discord": "message",
        "Telegram": "paperplane",
        "WhatsApp": "message",
        "Signal": "lock.shield",
        "Messages": "message.fill",
        "FaceTime": "video",
        "Zoom": "video.fill",
        "Microsoft Teams": "person.2.fill",
        "Skype": "phone",
        "Mattermost": "message",
        "Element": "message",
        "Mail": "envelope",
        "Spark": "envelope",
        "Airmail": "envelope",
        "Thunderbird": "envelope",
        "Outlook": "envelope",

        // Music & Media
        "Music": "music.note",
        "Spotify": "music.note",
        "Apple Music": "music.note",
        "iTunes": "music.note",
        "QuickTime Player": "play.circle",
        "VLC": "play.circle",
        "IINA": "play.circle",
        "MPV": "play.circle",
        "Podcasts": "mic",
        "Audacity": "waveform",
        "Logic Pro": "music.mic",
        "GarageBand": "music.mic",
        "Ableton Live": "music.note.list",
        "FL Studio": "music.note.list",

        // Productivity
        "Notes": "note.text",
        "Reminders": "list.bullet",
        "Calendar": "calendar",
        "Fantastical": "calendar",
        "Things": "list.bullet.rectangle",
        "Todoist": "checkmark.circle",
        "Notion": "doc.text",
        "Obsidian": "cube.box",
        "Bear": "pencil",
        "Ulysses": "pencil",
        "iA Writer": "pencil",
        "Evernote": "note.text",
        "OneNote": "note.text",
        "GoodNotes": "pencil.tip.crop.circle",
        "Notability": "pencil.tip.crop.circle",

        // Office
        "Word": "doc.text",
        "Microsoft Word": "doc.text",
        "Excel": "chart.bar",
        "Microsoft Excel": "chart.bar",
        "PowerPoint": "presentation",
        "Microsoft PowerPoint": "presentation",
        "Keynote": "presentation",
        "Pages": "doc.text",
        "Numbers": "chart.bar",
        "PDF Expert": "doc.richtext",
        "Adobe Acrobat": "doc.richtext",
        "Preview": "doc.on.doc",

        // Creative
        "Photoshop": "paintbrush",
        "Adobe Photoshop": "paintbrush",
        "Illustrator": "paintbrush.pointed",
        "Adobe Illustrator": "paintbrush.pointed",
        "Figma": "figma",
        "Sketch": "square.stack",
        "Affinity Designer": "paintbrush",
        "Affinity Photo": "camera",
        "Lightroom": "camera",
        "Adobe Lightroom": "camera",
        "Final Cut Pro": "film",
        "Premiere Pro": "film",
        "Adobe Premiere": "film",
        "DaVinci Resolve": "film",
        "After Effects": "sparkles",
        "Blender": "cube",
        "Cinema 4D": "cube",

        // System & Utilities
        "Finder": "folder",
        "System Settings": "gearshape",
        "System Preferences": "gearshape",
        "Activity Monitor": "gauge.medium",
        "Disk Utility": "externaldrive",
        "Console": "terminal",
        "Calculator": "calculator",
        "Dictionary": "book",
        "Maps": "map",
        "Weather": "cloud",
        "Clock": "clock",
        "Photo Booth": "camera",
        "Image Capture": "camera",
        "ColorSync Utility": "paintpalette",
        "Script Editor": "applescript",
        "Automator": "robot",
        "Shortcuts": "wrench.and.screwdriver",
        "Control Center": "switch.2",
        "Spotlight": "magnifyingglass",
        " Alfred": "magnifyingglass",
        "Raycast": "bolt",
        "1Password": "key",
        "Bitwarden": "key",
        "LastPass": "key",

        // File Management
        "Dropbox": "cloud",
        "Google Drive": "cloud",
        "OneDrive": "cloud",
        "Box": "cloud",
        "Synology Drive": "server.rack",
        "Transmit": "arrow.up.arrow.down",
        "Cyberduck": "link",
        "FileZilla": "arrow.up.arrow.down",

        // Virtualization
        "Parallels Desktop": "pc",
        "VMware Fusion": "pc",
        "VirtualBox": "pc",
        "UTM": "pc",

        // Gaming
        "Steam": "gamecontroller",
        "Epic Games": "gamecontroller",
        "Battle.net": "gamecontroller",
        "GOG Galaxy": "gamecontroller",
        "Origin": "gamecontroller",
        "Ubisoft Connect": "gamecontroller",
        "RetroArch": "gamecontroller",

        // Social Media
        "Twitter": "bird",
        "Tweetbot": "bird",
        "Facebook": "person.2",
        "Instagram": "camera",
        "LinkedIn": "person.badge.plus",
        "Reddit": "bubble.left.and.bubble.right",
        "TikTok": "video",
        "YouTube": "play.rectangle",
        "Twitch": "play.rectangle",

        // Finance
        "Stocks": "chart.line.uptrend.xyaxis",
        "Wallet": "wallet.pass",
        "MoneyMoney": "dollarsign.circle",
        "Coinbase": "dollarsign.circle",

        // Reading
        "Books": "book",
        "Kindle": "book",
        "Apple Books": "book",
        "Calibre": "book",

        // Password Managers
        "1Password 8": "key",
        "KeePassXC": "key",

        // Network Tools
        "Wireshark": "network",
        "Little Snitch": "shield",
        "Radio Silence": "shield",
        "LuLu": "shield",

        // Cleaners
        "CleanMyMac X": "trash",
        "OnyX": "wrench",
        "CCleaner": "trash",

        // Backup
        "Time Machine": "clock.arrow.circlepath",
        "Carbon Copy Cloner": "copy",
        "SuperDuper!": "externaldrive",

        // Remote Access
        "Screen Sharing": "display",
        "Microsoft Remote Desktop": "desktopcomputer",
        "TeamViewer": "desktopcomputer",
        "AnyDesk": "desktopcomputer",
        "Royal TSX": "server.rack",

        // Database Tools
        "TablePlus": "cylinder.split.1x2",
        "Sequel Pro": "cylinder.split.1x2",
        "Sequel Ace": "cylinder.split.1x2",
        "MySQL Workbench": "cylinder.split.1x2",
        "MongoDB Compass": "cylinder.split.1x2",
        "RedisInsight": "cylinder.split.1x2",
        "Postico": "cylinder.split.1x2",

        // API Tools
        "Postman": "paperplane",
        "Insomnia": "moon",
        "HTTPie": "paperplane",
        "Paw": "pawprint",

        // Note-taking (additional)
        "Craft": "doc.text",
        "Amplenote": "note.text",
        "Logseq": "circle.grid.cross",

        // AI Assistants
        "Copilot": "brain",
        "Cursor": "brain",
        "Claude": "brain",
        "ChatGPT": "brain",

        // Miscellaneous
        "Home Assistant": "house",
        "OBS": "video.circle",
        "Streamlabs": "video.circle",
        "Elgato Stream Deck": "switch.programmable",
        "Karabiner-Elements": "keyboard",
        "BetterTouchTool": "hand.tap",
        "Rectangle": "arrow.up.left.and.arrow.down.right",
        "Magnet": "arrow.up.left.and.arrow.down.right",
        "Bartender": "menubar.rectangle",
        "Stats": "chart.bar",
        "iStat Menus": "chart.bar",
        "MonitorControl": "sun.max",
        "Shifty": "moon",
        "Flux": "sun.max",
        "Night Shift": "moon",
    ]

    /// Get the SF Symbol name for an app
    static func symbolName(for appName: String?) -> String? {
        guard let appName = appName else { return nil }

        // Direct match
        if let symbol = symbolMappings[appName] {
            return symbol
        }

        // Case-insensitive match
        let lowercased = appName.lowercased()
        for (key, value) in symbolMappings {
            if key.lowercased() == lowercased {
                return value
            }
        }

        // Partial match - check if app name contains any mapped key
        for (key, value) in symbolMappings {
            if lowercased.contains(key.lowercased()) {
                return value
            }
        }

        return nil
    }

    /// Check if an app has a mapped SF Symbol
    static func hasSymbol(for appName: String?) -> Bool {
        return symbolName(for: appName) != nil
    }
}
