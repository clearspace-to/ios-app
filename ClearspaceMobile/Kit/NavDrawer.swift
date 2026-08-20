import SwiftUI

/// One nav destination in the drawer.
struct DrawerItem: Identifiable, Equatable {
    let id: String
    let label: String
    let icon: String
    /// Declared in the nav but without a screen yet — still rendered normally.
    var implemented: Bool = true
}

struct DrawerGroup: Identifiable {
    var id: String { label }
    let label: String
    let items: [DrawerItem]
}

/// Product entry in the drawer's app switcher.
struct DrawerApp: Identifiable, Equatable {
    let id: String
    let name: String
    let blurb: String
    var available: Bool = false
}

/// Full-height left navigation drawer: navy brand card with app switcher,
/// grouped nav cards, log out. Matches the sales_space iOS design.
struct NavDrawer: View {
    let currentApp: String
    let apps: [DrawerApp]
    let groups: [DrawerGroup]
    let selectedItemID: String
    let userInitials: String
    let onSelectItem: (DrawerItem) -> Void
    let onSelectApp: (DrawerApp) -> Void
    let onLogOut: () -> Void

    @State private var appsOpen = false

    private let cardRadius: CGFloat = 12
    private let sideInset: CGFloat = 14

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                brandCard
                if appsOpen {
                    appList.padding(.top, 10)
                }
                ForEach(groups) { group in
                    Text(group.label.uppercased())
                        .font(.system(size: 12, weight: .medium))
                        .kerning(0.5)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.top, 20)
                        .padding(.bottom, 7)
                    card {
                        ForEach(group.items) { item in
                            itemRow(item)
                            if item != group.items.last {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                }

                Button(action: onLogOut) {
                    Text("Log Out")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: cardRadius))
                }
                .buttonStyle(.plain)
                .padding(.top, 24)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, sideInset)
            .padding(.top, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Background bleeds into the status bar and home-indicator areas so the
        // drawer runs the full height of the screen; content stays in the safe area.
        .background(
            UnevenRoundedRectangle(bottomTrailingRadius: 28, topTrailingRadius: 28)
                .fill(Color(.systemGroupedBackground))
                .shadow(color: .black.opacity(0.28), radius: 22, x: 8)
                .ignoresSafeArea()
        )
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: cardRadius))
    }

    private var brandCard: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { appsOpen.toggle() }
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Image("logo-hero")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 18)
                    HStack(spacing: 5) {
                        Text(currentApp.uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .kerning(0.8)
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .rotationEffect(.degrees(appsOpen ? 180 : 0))
                    }
                }
                Spacer(minLength: 8)
                InitialsAvatar(text: userInitials, size: 32, background: .white.opacity(0.14))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Theme.navy, in: RoundedRectangle(cornerRadius: cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("drawer.brand")
    }

    private var appList: some View {
        card {
            ForEach(apps) { app in
                Button {
                    onSelectApp(app)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Theme.navy)
                                .frame(width: 32, height: 32)
                            Capsule()
                                .fill(Theme.blue)
                                .frame(width: 15, height: 4)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.system(size: 15, weight: app.name == currentApp ? .semibold : .regular))
                                .foregroundStyle(.primary)
                            Text(app.blurb)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        if app.name == currentApp {
                            Image(systemName: "checkmark")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.blue)
                        } else if !app.available {
                            Text("Soon")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("drawer.app.\(app.id)")
                if app != apps.last {
                    Divider().padding(.leading, 58)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func itemRow(_ item: DrawerItem) -> some View {
        let selected = item.id == selectedItemID
        return Button {
            onSelectItem(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(selected ? Theme.blue : Color.secondary)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selected ? Theme.blue.opacity(0.12) : Color(.tertiarySystemFill))
                    )
                Text(item.label)
                    .font(.system(size: 17))
                    .foregroundStyle(selected ? Theme.blue : .primary)
                Spacer(minLength: 4)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(selected ? Theme.blue.opacity(0.08) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
