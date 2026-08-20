import SwiftUI

/// Small colored capsule showing a stage or status.
struct StageBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.stageColor(text).opacity(0.15), in: Capsule())
            .foregroundStyle(Theme.stageColor(text))
            .lineLimit(1)
    }
}
