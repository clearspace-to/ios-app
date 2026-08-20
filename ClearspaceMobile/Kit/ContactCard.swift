import SwiftUI

/// Contact card with call/email quick actions (mockup: opportunity detail "Primary Contact").
struct ContactCard: View {
    let name: String
    var title: String?
    var phone: String?
    var email: String?

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(text: name, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.weight(.medium))
                if let title, !title.isEmpty {
                    Text(title).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let phone, let url = URL(string: "tel:" + phone.filter { !$0.isWhitespace }) {
                Link(destination: url) {
                    Image(systemName: "phone.fill")
                        .frame(width: 34, height: 34)
                        .background(Color(.systemFill), in: Circle())
                }
            }
            if let email, let url = URL(string: "mailto:" + email) {
                Link(destination: url) {
                    Image(systemName: "envelope.fill")
                        .frame(width: 34, height: 34)
                        .background(Color(.systemFill), in: Circle())
                }
            }
        }
    }
}
