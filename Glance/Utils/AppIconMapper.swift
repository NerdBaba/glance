import Foundation

/// Maps application names to SF Symbol names for consistent icon rendering
enum IconStyle: String, Decodable {
    case appIcon      // Original NSApp icons (with backgrounds)
    case sfSymbol    // SF Symbols (glyph-only, no background, tints properly)
}

struct AppIconMapper {
    /// Comprehensive mapping of app names to specific SF Symbols that match app logos
    /// These are glyph-only symbols without backgrounds - perfect for tinting
    private static let symbolMappings: [String: String] = [
        // Browsers - specific compass/globe icons
        "Safari": "safari",
        "Chrome": "circle.hexagongrid.fill",
        "Google Chrome": "circle.hexagongrid.fill",
        "Firefox": "flame",
        "Arc": "captions.bubble",
        "Brave": "lion",
        "Edge": "waveform.path.ecg",
        "Opera": "o.circle",
        "Vivaldi": "star",
        "Orion": "star.circle",

        // Development - specific tool icons
        "Xcode": "hammer",
        "Code": "curlybraces.square",
        "Visual Studio Code": "curlybraces.square",
        "VSCode": "curlybraces.square",
        "Sublime Text": "text.word",
        "iTerm2": "terminal.fill",
        "Terminal": "terminal.fill",
        "Warp": "command.square",
        "Ghostty": "ghost.fill",
        "Alacritty": "terminal.fill",
        "Android Studio": "android.app.fill",
        "IntelliJ IDEA": "square.stack.3d.up.fill",
        "PyCharm": "python",
        "WebStorm": "cloud.sun.rain.fill",
        "CLion": "leaf.fill",
        "Rider": "figure.outdoor.cycle",
        "PhpStorm": "sun.horizon.fill",
        "RubyMine": "gemstone.fill",
        "AppCode": "at.circle.fill",
        "DataGrip": "cylinder.split.1x2.fill",
        "GoLand": "goforward",
        "Nova": "nova",
        "BBEdit": "text.justify.left",
        "TextMate": "text.quotelevel",
        "MacVim": "modal.key.fill",
        "Docker": "shippingbox.fill",
        "Docker Desktop": "shippingbox.fill",
        "Simulator": "iphone",
        "Android Emulator": "android.app.fill",

        // Communication - specific app icons
        "Slack": "pound",
        "Discord": "gamecontroller.fill",
        "Telegram": "paperplane.fill",
        "WhatsApp": "phone.bubble.left.fill",
        "Signal": "lock.shield.fill",
        "Messages": "message.fill",
        "FaceTime": "video.fill",
        "Zoom": "video.badge.ellipsis",
        "Microsoft Teams": "person.2.wave.2",
        "Skype": "phone.connection",
        "Mattermost": "message.and.waveform",
        "Element": "atom",
        "Mail": "envelope.fill",
        "Spark": "envelope.open.fill",
        "Airmail": "paperplane.circle.fill",
        "Thunderbird": "bird.fill",
        "Outlook": "calendar.badge.clock",

        // Music & Media - specific player icons
        "Music": "music.note.list",
        "Spotify": "circle.grid.2x1",
        "Apple Music": "music.quarternote.3",
        "iTunes": "music.note.tv",
        "QuickTime Player": "play.circle.fill",
        "VLC": "traffic.cone",
        "IINA": "play.rectangle.fill",
        "MPV": "play.circle.fill",
        "Podcasts": "mic.fill",
        "Audacity": "waveform",
        "Logic Pro": "pianokeys",
        "GarageBand": "guitars.fill",
        "Ableton Live": "slider.horizontal.3",
        "FL Studio": "knob",

        // Productivity - specific app metaphors
        "Notes": "note.text",
        "Reminders": "list.bullet.clipboard.fill",
        "Calendar": "calendar",
        "Fantastical": "calendar.badge.clock",
        "Things": "circle.hexagongrid.circle",
        "Todoist": "checkmark.seal.fill",
        "Notion": "doc.text.image",
        "Obsidian": "sparkles",
        "Bear": "bear.fill",
        "Ulysses": "text.book.closed.fill",
        "iA Writer": "pencil.line",
        "Evernote": "notebook",
        "OneNote": "notebook.square",
        "GoodNotes": "hand.draw.fill",
        "Notability": "pencil.and.ruler.fill",

        // Office - document metaphors
        "Word": "doc.text.below.ecg",
        "Microsoft Word": "doc.text.below.ecg",
        "Excel": "tablecells.fill",
        "Microsoft Excel": "tablecells.fill",
        "PowerPoint": "play.square.stack",
        "Microsoft PowerPoint": "play.square.stack",
        "Keynote": "cursorarrow.click",
        "Pages": "doc.on.clipboard",
        "Numbers": "chart.bar.xaxis",
        "PDF Expert": "doc.richtext",
        "Adobe Acrobat": "doc.plaintext",
        "Preview": "magnifyingglass.circle",

        // Creative - tool-specific icons
        "Photoshop": "paintbrush.pointed.fill",
        "Adobe Photoshop": "paintbrush.pointed.fill",
        "Illustrator": "pen.tip",
        "Adobe Illustrator": "pen.tip",
        "Figma": "figma",
        "Sketch": "square.split.bottomrightquarter",
        "Affinity Designer": "paintbrush.fill",
        "Affinity Photo": "camera.metering.center.weighted.average",
        "Lightroom": "sun.max.trianglebadge.exclamationmark",
        "Adobe Lightroom": "sun.max.trianglebadge.exclamationmark",
        "Final Cut Pro": "film.fill",
        "Premiere Pro": "scissors",
        "Adobe Premiere": "scissors",
        "DaVinci Resolve": "wand.and.stars.inverse",
        "After Effects": "sparkles.rectangle.stack.fill",
        "Blender": "cube.transparent.fill",
        "Cinema 4D": "cube.box.fill",

        // System - actual system app icons
        "Finder": "folder.fill",
        "System Settings": "gearshape.2.fill",
        "System Preferences": "gearshape.2.fill",
        "Activity Monitor": "speedometer",
        "Disk Utility": "internaldrive.fill",
        "Console": "terminal.fill",
        "Calculator": "calculator",
        "Dictionary": "book.fill",
        "Maps": "map.fill",
        "Weather": "cloud.sun.fill",
        "Clock": "deskclock.fill",
        "Photo Booth": "camera.rotate.fill",
        "Image Capture": "camera.on.rectangle.fill",
        "ColorSync Utility": "paintpalette.fill",
        "Script Editor": "applescript.fill",
        "Automator": "gearshape.arrow.triangle.2.circlepath",
        "Shortcuts": "wrench.adjustable",
        "Control Center": "switch.2",
        "Spotlight": "magnifyingglass.circle.fill",
        "Alfred": "crown.fill",
        "Raycast": "bolt.horizontal.circle.fill",
        "1Password": "key.fill",
        "Bitwarden": "key.radiowaves.forward",
        "LastPass": "key.horizontal.fill",

        // File Management - cloud and transfer icons
        "Dropbox": "drop.triangle.fill",
        "Google Drive": "cloud.fill",
        "OneDrive": "cloud.fill",
        "Box": "archivebox.fill",
        "Synology Drive": "server.rack",
        "Transmit": "arrow.left.arrow.right.circle.fill",
        "Cyberduck": "link.circle.fill",
        "FileZilla": "arrow.up.arrow.down.square.fill",

        // Virtualization - computer icons
        "Parallels Desktop": "macbook.and.ipad",
        "VMware Fusion": "desktopcomputer.and.monitor",
        "VirtualBox": "macmini",
        "UTM": "cpu",

        // Gaming - controller icons
        "Steam": "gamecontroller.fill",
        "Epic Games": "staroflife.shield.fill",
        "Battle.net": "shield.lefthalf.filled",
        "GOG Galaxy": "galaxy.fill",
        "Origin": "gift.fill",
        "Ubisoft Connect": "hexagon.fill",
        "RetroArch": "gamecontroller.fill",

        // Social Media - platform-specific icons
        "Twitter": "bird.fill",
        "Tweetbot": "bird.fill",
        "Facebook": "person.3.fill",
        "Instagram": "camera.circle.fill",
        "LinkedIn": "person.crop.circle.badge.checkmark",
        "Reddit": "alien.fill",
        "TikTok": "music.mic",
        "YouTube": "play.rectangle.on.rectangle.fill",
        "Twitch": "flag.2.crossed.fill",

        // Finance - money icons
        "Stocks": "chart.line.uptrend.xyaxis.circle.fill",
        "Wallet": "wallet.pass.fill",
        "MoneyMoney": "dollarsign.arrow.circlepath",
        "Coinbase": "dollarsign.circle.fill",

        // Reading - book icons
        "Books": "book.fill",
        "Kindle": "book.closed.fill",
        "Apple Books": "sparkles.book.fill",
        "Calibre": "books.vertical.fill",

        // Password Managers (additional)
        "1Password 8": "key.fill",
        "KeePassXC": "key.radiowaves.forward",

        // Network Tools - security icons
        "Wireshark": "magnifyingglass.circle.badge.ellipsis",
        "Little Snitch": "antenna.radiowaves.left.and.right.slash",
        "Radio Silence": "speaker.slash.fill",
        "LuLu": "antenna.radiowaves.left.and.right.slash",

        // Cleaners - maintenance icons
        "CleanMyMac X": "trash.circle.fill",
        "OnyX": "wrench.and.screwdriver.fill",
        "CCleaner": "xmark.bin.fill",

        // Backup - storage icons
        "Time Machine": "timelapse",
        "Carbon Copy Cloner": "copy.fill",
        "SuperDuper!": "externaldrive.connected.to.line.below.fill",

        // Remote Access - screen sharing icons
        "Screen Sharing": "display.2",
        "Microsoft Remote Desktop": "desktopcomputer.and.monitor",
        "TeamViewer": "cursorarrow.motionlines.click",
        "AnyDesk": "cursorarrow.square",
        "Royal TSX": "server.rack",

        // Database Tools - data icons
        "TablePlus": "cylinder.split.1x2.fill",
        "Sequel Pro": "cylinder.split.1x2.fill",
        "Sequel Ace": "cylinder.split.1x2.fill",
        "MySQL Workbench": "wrench.and.hammer.fill",
        "MongoDB Compass": "compass.drawing",
        "RedisInsight": "bolt.horizontal.fill",
        "Postico": "elephant.fill",

        // API Tools - network request icons
        "Postman": "paperplane.circle.fill",
        "Insomnia": "moon.zzz.fill",
        "HTTPie": "flame.circle.fill",
        "Paw": "pawprint.fill",

        // Note-taking (additional)
        "Craft": "scissors.badge.ellipsis",
        "Amplenote": "music.note.list",
        "Logseq": "diagram.semi filled",

        // AI Assistants - brain/AI icons
        "Copilot": "brain.filled.head.profile",
        "Cursor": "cursorarrow.rays",
        "Claude": "brain.head.profile",
        "ChatGPT": "brain.filled.head.profile",

        // Miscellaneous - utility icons
        "Home Assistant": "house.lodge.fill",
        "OBS": "video.circle.fill",
        "Streamlabs": "video.badge.waveform.fill",
        "Elgato Stream Deck": "button.programmable",
        "Karabiner-Elements": "keyboard.badge.ellipsis",
        "BetterTouchTool": "hand.tap.fill",
        "Rectangle": "arrow.up.left.and.arrow.down.right.square.fill",
        "Magnet": "magnet.fill",
        "Bartender": "menubar.dock.rectangle",
        "Stats": "chart.bar.fill",
        "iStat Menus": "gauge.with.dots.needle.bottomleft.50percent",
        "MonitorControl": "sun.max.fill",
        "Shifty": "moon.stars.fill",
        "Flux": "sun.max.fill",
        "Night Shift": "moon.zzz.fill",
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
