import SwiftUI

struct SpaceSelectorView: View {
    let modules: [AppModule]
    let onSelect: (String) -> Void

    private let icons: [String: String] = [
        "safe_space": "shield.checkered",
        "sales_space": "chart.line.uptrend.xyaxis",
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Clearspace")
                    .font(.largeTitle.weight(.bold))
                Text("Choose a space to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                ForEach(modules.filter(\.available)) { module in
                    Button { onSelect(module.id) } label: {
                        HStack(spacing: 16) {
                            Image(systemName: icons[module.id] ?? "square.grid.2x2")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(module.name)
                                    .font(.headline)
                                Text(module.blurb)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }
}
