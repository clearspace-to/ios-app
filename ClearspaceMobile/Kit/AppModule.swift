import SwiftUI

/// A pushable detail screen. One route type for every module keeps the shell's
/// navigation registration to a single `navigationDestination`.
struct DetailRoute: Hashable {
    let module: String
    let kind: String
    let id: String
}

/// Where a search result sends you.
enum NavTarget: Hashable {
    case screen(String)          // a destination id in the module's nav
    case detail(DetailRoute)
}

/// One command-bar result contributed by a module.
struct ModuleSearchHit: Identifiable {
    let id: String
    /// Section title in the palette, e.g. "Projects".
    let group: String
    let icon: String
    let title: String
    var subtitle: String?
    let target: NavTarget
}

/// Everything the shell needs to host one Clearspace product.
/// Adding an app means writing one of these plus its screens — no shell changes.
struct AppModule: Identifiable {
    let id: String
    let name: String
    let blurb: String
    /// False for products not yet built into the app; they show as "Soon".
    var available: Bool = true

    var navGroups: [DrawerGroup] = []
    var defaultDestination: String = ""
    var createActions: [String] = []
    var createSheetTitle: String = ""

    /// Search sections in the order they should appear, before scoping.
    var searchGroups: [String] = []
    /// The section to float to the top given the screen you're on.
    var primarySearchGroup: (String) -> String? = { _ in nil }

    var createView: (String) -> AnyView? = { _ in nil }
    var screen: (String) -> AnyView = { _ in AnyView(EmptyView()) }
    var detail: (DetailRoute) -> AnyView = { _ in AnyView(EmptyView()) }
    var search: (String) async -> [ModuleSearchHit] = { _ in [] }
    /// Start loading the search index before the user types anything.
    var warmSearch: (() -> Void)?
}

/// Convenience for modules that only expose "coming soon" in the app switcher.
extension AppModule {
    static func placeholder(id: String, name: String, blurb: String) -> AppModule {
        AppModule(id: id, name: name, blurb: blurb, available: false)
    }
}
