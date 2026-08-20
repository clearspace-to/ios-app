import SwiftUI

/// A label–value row inside a grouped detail section.
/// Value kinds get the right formatting and tap behavior (call, email, open URL).
struct FieldRow: View {
    enum Kind {
        case text
        case currency
        case date
        case phone
        case email
        case url
    }

    let label: String
    let value: String?
    var kind: Kind = .text

    var body: some View {
        switch kind {
        case .phone:
            linkRow(scheme: "tel:", display: value)
        case .email:
            linkRow(scheme: "mailto:", display: value)
        case .url:
            if let value, let url = URL(string: value) {
                Link(destination: url) { labeled(display: value, color: Theme.blue) }
            } else {
                labeled(display: value)
            }
        default:
            labeled(display: value)
        }
    }

    private func linkRow(scheme: String, display: String?) -> some View {
        Group {
            if let display, let url = URL(string: scheme + display.filter { !$0.isWhitespace }) {
                Link(destination: url) { labeled(display: display, color: Theme.blue) }
            } else {
                labeled(display: display)
            }
        }
    }

    private func labeled(display: String?, color: Color? = nil) -> some View {
        LabeledContent(label) {
            Text(display?.isEmpty == false ? display! : "—")
                .foregroundStyle(color ?? .secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
