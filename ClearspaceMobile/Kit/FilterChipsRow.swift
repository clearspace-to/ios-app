import SwiftUI

/// Horizontally scrolling filter chips (mockup: stage filter on Opportunities).
struct FilterChipsRow: View {
    let options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isOn = selected.contains(option)
                    Button {
                        if isOn { selected.remove(option) } else { selected.insert(option) }
                    } label: {
                        Text(option)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isOn ? Theme.blue : Color(.systemFill), in: Capsule())
                            .foregroundStyle(isOn ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}
