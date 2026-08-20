import SwiftUI

/// Universal list row: optional avatar, title + subtitle, trailing value and/or badge.
/// Covers every list in the mockups (opportunities, accounts, contacts, buildings, revisions).
struct RecordRow: View {
    var avatarText: String?
    var avatarColor: Color = Theme.blue
    var monogramPrefix: String? // e.g. opportunity number shown before the title
    let title: String
    var subtitle: String?
    var trailingValue: String?  // e.g. fees
    var badge: String?          // e.g. stage

    var body: some View {
        HStack(spacing: 12) {
            if let avatarText {
                InitialsAvatar(text: avatarText, size: 38, background: avatarColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let monogramPrefix {
                        Text(monogramPrefix)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    Text(title)
                        .font(.body)
                        .lineLimit(1)
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                if let trailingValue {
                    Text(trailingValue)
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                }
                if let badge {
                    StageBadge(text: badge)
                }
            }
            .fixedSize()
        }
        .contentShape(Rectangle())
    }
}
