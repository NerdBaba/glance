import SwiftUI

// MARK: - Curated Icon List

struct CuratedIcons {
    static let all: [(symbol: String, label: String)] = [
        // Desktop
        ("desktopcomputer", "Desktop"),
        ("laptopcomputer", "Laptop"),
        ("server.rack", "Server"),
        // Apps
        ("app", "App"),
        ("globe", "Browser"),
        ("terminal.fill", "Terminal"),
        ("gearshape.fill", "Settings"),
        ("music.note", "Music"),
        // Communication
        ("bubble.left", "Chat"),
        ("phone.fill", "Phone"),
        ("envelope.fill", "Mail"),
        // Work
        ("briefcase.fill", "Work"),
        ("hammer.fill", "Tools"),
        ("wrench.adjustable", "Wrench"),
        ("square.grid.3x1.fill", "Grid"),
        // Media
        ("play.circle.fill", "Play"),
        ("camera.fill", "Camera"),
        ("mic.fill", "Mic"),
        ("speaker.wave.3.fill", "Speaker"),
        // System
        ("wifi", "WiFi"),
        ("battery.100", "Battery"),
        ("sun.max.fill", "Sun"),
        ("moon.fill", "Moon"),
        ("star.fill", "Star"),
        // Navigation
        ("location.fill", "Location"),
        ("map.fill", "Map"),
        ("globe.americas.fill", "Globe"),
        ("house.fill", "Home"),
        // Generic
        ("circle.fill", "Circle"),
        ("square.fill", "Square"),
        ("triangle.fill", "Triangle"),
        ("heart.fill", "Heart"),
        ("bolt.fill", "Bolt"),
        ("flame.fill", "Flame"),
        ("cloud.fill", "Cloud"),
        ("drop.fill", "Drop"),
        ("leaf.fill", "Leaf"),
        // Gaming
        ("gamecontroller.fill", "Gaming"),
        ("die.face.5", "Dice"),
        ("puzzlepiece.fill", "Puzzle"),
        // Productivity
        ("doc.fill", "Document"),
        ("folder.fill", "Folder"),
        ("calendar", "Calendar"),
        ("clock.fill", "Clock"),
        ("list.bullet", "List"),
        ("checkmark.seal.fill", "Check"),
        ("pencil", "Edit"),
        ("magnifyingglass", "Search"),
        // Code
        ("curlybraces", "Code"),
        ("command", "Command"),
        ("option", "Option"),
        ("shift", "Shift"),
        ("escape", "Escape"),
        // Finance
        ("dollarsign.circle.fill", "Finance"),
        ("creditcard.fill", "Card"),
        ("chart.bar.fill", "Chart"),
        // Health
        ("heart.text.square.fill", "Health"),
        ("figure.walk", "Walk"),
        ("bed.double.fill", "Sleep"),
        // Social
        ("person.fill", "Person"),
        ("person.2.fill", "People"),
        ("person.3.fill", "Group"),
        ("bubble.left.and.bubble.right.fill", "Messages"),
        // Security
        ("lock.fill", "Lock"),
        ("shield.fill", "Shield"),
        ("key.fill", "Key"),
        ("touchid", "Touch ID"),
    ]

    static func search(_ query: String) -> [(symbol: String, label: String)] {
        guard !query.isEmpty else { return [] }
        let lower = query.lowercased()
        return all.filter { $0.symbol.lowercased().contains(lower) || $0.label.lowercased().contains(lower) }
    }
}

// MARK: - Icon Picker View

struct IconPickerView: View {
    @Binding var selectedIcon: String
    let recentIcons: [String]
    let onIconSelected: (String) -> Void
    let onDismiss: (() -> Void)?

    @State private var searchText = ""

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var filteredIcons: [(symbol: String, label: String)] {
        if searchText.isEmpty {
            return CuratedIcons.all
        }
        let results = CuratedIcons.search(searchText)
        return results.isEmpty ? CuratedIcons.all : results
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("Choose Icon")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    onDismiss?()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Searchable scroll content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Recent icons
                    if !recentIcons.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(recentIcons.prefix(6), id: \.self) { symbol in
                                    IconGridItem(symbol: symbol, label: symbol, isSelected: symbol == selectedIcon) {
                                        onIconSelected(symbol)
                                    }
                                }
                            }
                        }
                    }

                    // Curated grid
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icons")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(filteredIcons, id: \.symbol) { item in
                                IconGridItem(symbol: item.symbol, label: item.label, isSelected: item.symbol == selectedIcon) {
                                    onIconSelected(item.symbol)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .searchable(text: $searchText, prompt: "Search SF Symbols...")
        }
        .frame(width: 520, height: 480)
    }
}

// MARK: - Grid Item

private struct IconGridItem: View {
    let symbol: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .frame(height: 28)
                Text(label)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
