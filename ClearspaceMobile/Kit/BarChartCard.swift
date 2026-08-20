import SwiftUI
import Charts

struct BarPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

/// Simple bar chart card (mockup: "Weekly Identified — Last 8 weeks").
/// Uses Apple's built-in Swift Charts.
struct BarChartCard: View {
    let title: String
    var subtitle: String?
    let points: [BarPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Chart(points) { point in
                BarMark(
                    x: .value("Label", point.label),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Theme.blue)
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 140)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
