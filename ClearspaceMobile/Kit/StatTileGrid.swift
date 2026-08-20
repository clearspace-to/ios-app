import SwiftUI

struct StatTile: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var color: Color = .primary
}

/// 2-column dashboard stat tiles (mockup: Dashboard top grid).
struct StatTileGrid: View {
    let tiles: [StatTile]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            ForEach(tiles) { tile in
                VStack(alignment: .leading, spacing: 8) {
                    Text(tile.label.uppercased())
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(tile.value)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(tile.color)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
