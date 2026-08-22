import SwiftUI

/// The Clearspace mobile shell, shared by every product: floating liquid-glass
/// bottom bar (menu · command palette · create), full-height nav drawer with the
/// app switcher, command palette, create sheet and toast.
///
/// The shell knows nothing about any specific app — it renders whichever
/// `AppModule` is selected.
struct AppShell: View {
    let modules: [AppModule]

    @EnvironmentObject private var auth: AuthManager
    @State private var moduleID: String
    @State private var destination: String
    @State private var path = NavigationPath()
    @State private var drawerOpen = false
    @State private var paletteOpen = false
    @State private var createOpen = false
    @State private var paletteQuery = ""
    @State private var hits: [ModuleSearchHit] = []
    @State private var activeCreate: CreateAction?
    @State private var toast: String?

    init(modules: [AppModule]) {
        self.modules = modules
        let first = modules.first { $0.available } ?? modules[0]
        _moduleID = State(initialValue: first.id)
        _destination = State(initialValue: first.defaultDestination)
    }

    private var module: AppModule {
        modules.first { $0.id == moduleID } ?? modules[0]
    }

    private var drawerApps: [DrawerApp] {
        modules.map { DrawerApp(id: $0.id, name: $0.name, blurb: $0.blurb, available: $0.available) }
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                module.screen(destination)
                    .navigationDestination(for: DetailRoute.self) { route in
                        modules.first { $0.id == route.module }?.detail(route)
                    }
            }
            .overlay(alignment: .bottom) {
                if !paletteOpen {
                    BottomBar(
                        onMenu: { withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { drawerOpen = true } },
                        onSearch: { paletteOpen = true },
                        onCreate: { createOpen = true }
                    )
                    .padding(.bottom, BottomBarMetrics.bottomPadding)
                }
            }

            if drawerOpen {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { closeDrawer() }
                HStack(spacing: 0) {
                    NavDrawer(
                        currentApp: module.name,
                        apps: drawerApps,
                        groups: module.navGroups,
                        selectedItemID: destination,
                        userInitials: auth.user?.initials ?? "AN",
                        onSelectItem: select,
                        onSelectApp: selectApp,
                        onLogOut: { auth.signOut() }
                    )
                    .frame(width: UIScreen.main.bounds.width * 0.85)
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .leading))
            }

            if paletteOpen {
                CommandPaletteView(
                    query: $paletteQuery,
                    groups: paletteGroups,
                    onCancel: closePalette
                )
                .transition(.opacity)
            }

            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.88), in: Capsule())
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: drawerOpen)
        .animation(.easeInOut(duration: 0.18), value: paletteOpen)
        .animation(.easeInOut(duration: 0.2), value: toast != nil)
        .task(id: paletteQuery + moduleID) {
            hits = await module.search(paletteQuery)
        }
        .onAppear(perform: applyLaunchArguments)
        .confirmationDialog(module.createSheetTitle, isPresented: $createOpen, titleVisibility: .visible) {
            ForEach(module.createActions, id: \.self) { action in
                Button(action) {
                    if module.createView(action) != nil {
                        activeCreate = CreateAction(id: action)
                    } else {
                        flash("\(action) — coming soon")
                    }
                }
            }
        }
        .sheet(item: $activeCreate) { action in
            module.createView(action.id)
        }
    }

    // MARK: - Navigation

    private func go(to destinationID: String) {
        destination = destinationID
        path = NavigationPath()
    }

    private func select(_ item: DrawerItem) {
        closeDrawer()
        guard item.implemented else {
            flash("\(item.label) — coming soon")
            return
        }
        go(to: item.id)
    }

    private func selectApp(_ app: DrawerApp) {
        closeDrawer()
        guard let target = modules.first(where: { $0.id == app.id }), target.available else {
            flash("\(app.name) — coming soon")
            return
        }
        guard target.id != moduleID else { return }
        moduleID = target.id
        go(to: target.defaultDestination)
    }

    private func follow(_ target: NavTarget) {
        closePalette()
        switch target {
        case .screen(let id):
            go(to: id)
        case .detail(let route):
            path.append(route)
        }
    }

    private func closeDrawer() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { drawerOpen = false }
    }

    private func closePalette() {
        paletteOpen = false
        paletteQuery = ""
    }

    private func flash(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(1.9))
            toast = nil
        }
    }

    // MARK: - Command bar
    //
    // Records from the screen you're on come first, then the module's other
    // record types, then navigation commands.

    private var paletteGroups: [PaletteGroup] {
        let q = paletteQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [navigationGroup(matching: "")] }

        let primary = module.primarySearchGroup(destination)
        let order = [primary].compactMap { $0 } + module.searchGroups.filter { $0 != primary }

        var groups: [PaletteGroup] = order.compactMap { group in
            let matches = hits.filter { $0.group == group }
            guard !matches.isEmpty else { return nil }
            return PaletteGroup(label: group, items: matches.map { hit in
                PaletteResult(id: hit.id, title: hit.title, subtitle: hit.subtitle, icon: hit.icon) {
                    follow(hit.target)
                }
            })
        }

        let nav = navigationGroup(matching: q)
        if !nav.items.isEmpty { groups.append(nav) }
        return groups
    }

    private func navigationGroup(matching q: String) -> PaletteGroup {
        let items = module.navGroups.flatMap(\.items)
            .filter { q.isEmpty || $0.label.localizedCaseInsensitiveContains(q) }
            .map { item in
                PaletteResult(id: "nav-\(item.id)", title: item.label, icon: item.icon) {
                    closePalette()
                    guard item.implemented else {
                        flash("\(item.label) — coming soon")
                        return
                    }
                    go(to: item.id)
                }
            }
        return PaletteGroup(label: "Go To", items: items)
    }

    // MARK: - Create

    struct CreateAction: Identifiable {
        let id: String
    }

    // MARK: - Tooling hooks (screenshots / UI tests)

    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let arg = args.first(where: { $0.hasPrefix("-app=") }) {
            let id = String(arg.dropFirst("-app=".count))
            if let target = modules.first(where: { $0.id == id && $0.available }) {
                moduleID = target.id
                destination = target.defaultDestination
            }
        }
        if let arg = args.first(where: { $0.hasPrefix("-screen=") }) {
            destination = String(arg.dropFirst("-screen=".count))
        }
        if args.contains("-drawer") { drawerOpen = true }
        if args.contains("-palette") { paletteOpen = true }
    }
}
