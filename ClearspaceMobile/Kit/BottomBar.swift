import SwiftUI

/// The Clearspace floating bottom bar — design treatment "A · Split":
/// three separate liquid-glass elements: menu circle · command pill · compose circle.
struct BottomBar: View {
    let onMenu: () -> Void
    let onSearch: () -> Void
    let onCreate: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) { bar }
        } else {
            bar
        }
    }

    private var bar: some View {
        HStack(spacing: 10) {
            Button(action: onMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .liquidGlass(in: Circle())
            }
            .accessibilityIdentifier("bottomBar.menu")
            .accessibilityLabel("Menu")

            Button(action: onSearch) {
                HStack(spacing: 9) {
                    // Clearspace underscore mark on the navy chip
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.navy)
                            .frame(width: 36, height: 36)
                        Capsule()
                            .fill(Theme.blue)
                            .frame(width: 17, height: 4)
                    }
                    Text("Search or run a command")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 6)
                .padding(.trailing, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .liquidGlass(in: Capsule())
            }
            .accessibilityIdentifier("bottomBar.search")

            Button(action: onCreate) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .liquidGlass(in: Circle())
            }
            .accessibilityIdentifier("bottomBar.create")
            .accessibilityLabel("Create")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }
}
