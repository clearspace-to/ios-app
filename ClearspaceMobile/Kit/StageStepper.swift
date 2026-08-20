import SwiftUI

/// Horizontal pipeline-stage progress indicator (mockup: opportunity detail header).
struct StageStepper: View {
    let stages: [String]
    let current: String

    var body: some View {
        let currentIndex = stages.firstIndex { $0.caseInsensitiveCompare(current) == .orderedSame } ?? 0
        HStack(spacing: 4) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                VStack(spacing: 5) {
                    Capsule()
                        .fill(index <= currentIndex ? Theme.blue : Color(.systemFill))
                        .frame(height: 4)
                    Text(stage)
                        .font(.system(size: 10))
                        .foregroundStyle(index == currentIndex ? .primary : .secondary)
                        .fontWeight(index == currentIndex ? .medium : .regular)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
}
