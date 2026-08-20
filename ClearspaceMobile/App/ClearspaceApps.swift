import Foundation

/// Every Clearspace product the app knows about, in app-switcher order.
/// Built modules come first; the rest appear as "Soon".
///
/// Later: filter this by the user's `auth_app_access` grants so people only see
/// the apps they can open.
enum ClearspaceApps {
    static let all: [AppModule] = [
        SalesSpaceModule.module,
        SafeSpaceModule.module,
        .placeholder(id: "slt_dashboard", name: "SLT dashboard", blurb: "Leadership initiatives and pulse"),
        .placeholder(id: "vlt_dashboard", name: "VLT dashboard", blurb: "Verve leadership initiatives"),
        .placeholder(id: "clear_view", name: "clear_view", blurb: "Project profitability and FPU"),
        .placeholder(id: "clear_care", name: "ClearCare", blurb: "Warranty, projects, invoices"),
        .placeholder(id: "note_space", name: "NoteSpace", blurb: "Docs and meeting notes"),
    ]
}
