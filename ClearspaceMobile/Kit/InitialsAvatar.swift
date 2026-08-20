import SwiftUI

/// Circular initials avatar used in record rows and contact cards.
struct InitialsAvatar: View {
    let text: String
    var size: CGFloat = 40
    var background: Color = Theme.blue

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(background, in: Circle())
    }

    private var initials: String {
        let parts = text.split(separator: " ").prefix(2)
        if parts.count >= 2 {
            return parts.map { String($0.prefix(1)).uppercased() }.joined()
        }
        return String(text.prefix(2)).uppercased()
    }
}
