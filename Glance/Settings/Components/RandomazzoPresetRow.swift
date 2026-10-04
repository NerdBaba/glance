import SwiftUI

struct RandomazzoPresetRow: View {
  let entry: RandomazzoEntry
  let unavailable: Bool

  private static let companions = [
    "🍓", "🍒", "🍑", "🦊", "🐼", "🐸", "🐻", "🐰",
    "🐱", "🐥", "🌷", "🍀", "🌻", "🍄", "🐙", "🦋",
    "🌙", "⭐️", "🍡", "🧸", "🌈", "🪁", "🪷", "🪴",
    "☁️", "🫧", "🐣", "🐝", "🧁", "🍩", "🥨", "🍪",
  ]
  private static let tints: [Color] = [.pink, .purple, .teal, .blue, .orange, .green, .mint, .cyan]
  private var seed: UInt32 { entry.iconSeed ?? 0 }

  var body: some View {
    HStack(spacing: 14) {
      Text(Self.companions[Int(seed % UInt32(Self.companions.count))])
        .font(.system(size: 26))
        .frame(width: 46, height: 46)
        .background(
          Self.tints[Int((seed / 32) % UInt32(Self.tints.count))].opacity(0.15),
          in: RoundedRectangle(cornerRadius: 13)
        )
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 5) {
        Text(entry.name).font(.body.weight(.medium)).lineLimit(2)
          .help(entry.name)
        HStack(spacing: 5) {
          Text("Saved")
          Text(entry.savedAt, format: .dateTime.month(.abbreviated).day().year())
        }
        .font(.caption).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      VStack(alignment: .trailing, spacing: 5) {
        if unavailable {
          Label("Unavailable", systemImage: "exclamationmark.triangle")
            .font(.caption).foregroundStyle(.orange)
            .help("This preset’s file is missing or cannot be parsed.")
        } else {
          Text(entry.lastRolled == nil ? "Not tried yet" : "Last used")
            .font(.caption).foregroundStyle(.secondary)
        }
        if let date = entry.lastRolled {
          Text(date, format: .dateTime.month(.abbreviated).day())
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      .fixedSize(horizontal: true, vertical: false)
    }
    .padding(.vertical, 5)
  }
}
