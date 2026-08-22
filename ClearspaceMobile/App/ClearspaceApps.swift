import Foundation

/// Every Clearspace product the app knows about, in app-switcher order.
/// Built modules come first; the rest appear as "Soon".
///
/// Later: filter this by the user's `auth_app_access` grants so people only see
/// the apps they can open.
enum ClearspaceApps {
    static let all: [AppModule] = [
        SafeSpaceModule.module,
        SalesSpaceModule.module,
    ]
}
