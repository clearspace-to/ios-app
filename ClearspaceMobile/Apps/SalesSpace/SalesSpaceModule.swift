import SwiftUI

/// sales_space wired into the shared shell.
enum SalesSpaceModule {
    static let id = "sales_space"

    /// Sample data until sales_space's /api/v1 accepts bearer tokens.
    static var service: SalesSpaceService { MockSalesSpaceService() }

    static func route(for opportunity: Opportunity) -> DetailRoute {
        DetailRoute(module: id, kind: "opportunity", id: String(opportunity.id))
    }

    static var module: AppModule {
        AppModule(
            id: id,
            name: "sales_space",
            blurb: "CRM — opportunities, accounts, pipeline",
            navGroups: [
                DrawerGroup(label: "Primary", items: [
                    DrawerItem(id: "dashboard", label: "Dashboard", icon: "house"),
                    DrawerItem(id: "pipeline", label: "Pipeline", icon: "chart.bar"),
                    DrawerItem(id: "reports", label: "Reports", icon: "doc.text", implemented: false),
                ]),
                DrawerGroup(label: "Records", items: [
                    DrawerItem(id: "opportunities", label: "Opportunities", icon: "chart.line.uptrend.xyaxis"),
                    DrawerItem(id: "accounts", label: "Accounts", icon: "building.2"),
                    DrawerItem(id: "contacts", label: "Contacts", icon: "person"),
                    DrawerItem(id: "buildings", label: "Buildings", icon: "building"),
                    DrawerItem(id: "revisions", label: "Revisions", icon: "doc.on.clipboard"),
                ]),
                DrawerGroup(label: "Utility", items: [
                    DrawerItem(id: "settings", label: "Settings", icon: "gearshape"),
                    DrawerItem(id: "notifications", label: "Notifications", icon: "bell", implemented: false),
                ]),
            ],
            defaultDestination: "dashboard",
            createActions: ["New Opportunity", "New Account", "New Contact", "New Building"],
            createSheetTitle: "Create a new record in sales_space",
            searchGroups: SearchScope.allCases.map(\.title),
            primarySearchGroup: { destination in
                switch destination {
                case "accounts": return SearchScope.accounts.title
                case "contacts": return SearchScope.contacts.title
                case "buildings": return SearchScope.buildings.title
                case "revisions": return SearchScope.revisions.title
                default: return SearchScope.opportunities.title
                }
            },
            screen: { destination in
                switch destination {
                case "pipeline": return AnyView(PipelineView(service: service))
                case "opportunities": return AnyView(OpportunitiesView(service: service))
                case "accounts": return AnyView(RecordListView(service: service, kind: .accounts))
                case "contacts": return AnyView(RecordListView(service: service, kind: .contacts))
                case "buildings": return AnyView(RecordListView(service: service, kind: .buildings))
                case "revisions": return AnyView(RecordListView(service: service, kind: .revisions))
                case "settings": return AnyView(SettingsView(dataSource: "Sample data — API pending"))
                default: return AnyView(SalesDashboardView(service: service))
                }
            },
            detail: { route in
                guard route.kind == "opportunity", let id = Int(route.id) else {
                    return AnyView(EmptyView())
                }
                return AnyView(OpportunityDetailView(service: service, opportunityID: id))
            },
            search: { query in
                let hits = (try? await service.search(query: query)) ?? []
                return hits.map { hit in
                    ModuleSearchHit(
                        id: hit.id,
                        group: hit.scope.title,
                        icon: hit.scope.icon,
                        title: hit.title,
                        subtitle: hit.subtitle,
                        target: hit.opportunity.map { .detail(route(for: $0)) }
                            ?? .screen(hit.scope.recordKind?.rawValue ?? "opportunities")
                    )
                }
            }
        )
    }
}
