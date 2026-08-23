import SwiftUI

/// safe_space wired into the shared shell.
///
/// Note on auth: safe_space's API already accepts `Authorization: Bearer <token>`
/// issued by the SHARED Clearspace auth project (lwerfpaarwndjgovyykl), and gates
/// on `auth_app_access`. No backend change is needed here — only that the app
/// signs in against that project. See AuthConfig.
enum SafeSpaceModule {
    static let id = "safe_space"
    static var lastViewedProjectNumber: String?

    /// Live against safe.clearspace.to; sample data in preview/test runs.
    /// Computed, so switching into sample-data mode after launch takes effect.
    static var service: SafeSpaceService {
        AppEnvironment.isPreview ? MockSafeSpaceService() : LiveSafeSpaceService()
    }

    static func projectRoute(_ number: String) -> DetailRoute {
        DetailRoute(module: id, kind: "project", id: number)
    }

    static func talkRoute(_ talkID: String) -> DetailRoute {
        DetailRoute(module: id, kind: "talk", id: talkID)
    }

    static func formRoute(_ submissionID: String) -> DetailRoute {
        DetailRoute(module: id, kind: "form", id: submissionID)
    }

    static func reportRoute(_ reportID: String) -> DetailRoute {
        DetailRoute(module: id, kind: "report", id: reportID)
    }

    static var module: AppModule {
        AppModule(
            id: id,
            name: "safe_space",
            blurb: "Site safety — talks, forms, daily reports",
            navGroups: [
                // Projects leads, matching the web app's nav order.
                DrawerGroup(label: "Primary", items: [
                    DrawerItem(id: "projects", label: "Projects", icon: "folder"),
                    DrawerItem(id: "talks", label: "Toolbox Talks", icon: "person.2.wave.2"),
                    DrawerItem(id: "forms", label: "Forms", icon: "list.bullet.clipboard"),
                    DrawerItem(id: "daily", label: "Daily Reports", icon: "sun.max"),
                    DrawerItem(id: "fpus", label: "FPUs", icon: "percent"),
                ]),
                DrawerGroup(label: "Library", items: [
                    DrawerItem(id: "topics", label: "Talk Topics", icon: "book", implemented: false),
                    DrawerItem(id: "templates", label: "Form Templates", icon: "doc.badge.gearshape", implemented: false),
                ]),
                DrawerGroup(label: "Utility", items: [
                    DrawerItem(id: "settings", label: "Settings", icon: "gearshape"),
                ]),
            ],
            defaultDestination: "projects",
            createActions: ["Log FPU", "New Toolbox Talk", "New Daily Report", "Fill a Form"],
            createSheetTitle: "Create a new record in safe_space",
            searchGroups: SafetySearchScope.allCases.map(\.title),
            primarySearchGroup: { destination in
                switch destination {
                case "talks": return SafetySearchScope.talks.title
                case "forms": return SafetySearchScope.forms.title
                case "daily": return SafetySearchScope.reports.title
                default: return SafetySearchScope.projects.title
                }
            },
            createView: { action in
                switch action {
                case "Log FPU":
                    return AnyView(FpuEntryFormView(service: service))
                case "New Daily Report":
                    return AnyView(DailyReportFormView(service: service))
                case "New Toolbox Talk":
                    return AnyView(ToolboxTalkFormView(service: service))
                default:
                    return nil
                }
            },
            screen: { destination in
                switch destination {
                case "talks": return AnyView(ToolboxTalksView(service: service))
                case "forms": return AnyView(FormSubmissionsView(service: service))
                case "daily": return AnyView(DailyReportsView(service: service))
                case "fpus": return AnyView(FpusView(service: service))
                case "settings": return AnyView(SettingsView(dataSource: "Live · safe.clearspace.to"))
                default: return AnyView(SafetyProjectsView(service: service))
                }
            },
            detail: { route in
                switch route.kind {
                case "project": return AnyView(SafetyProjectDetailView(service: service, projectNumber: route.id))
                case "talk": return AnyView(ToolboxTalkDetailView(service: service, talkID: route.id))
                case "form": return AnyView(FormSubmissionDetailView(service: service, submissionID: route.id))
                case "report": return AnyView(DailyReportDetailView(service: service, reportID: route.id))
                default: return AnyView(EmptyView())
                }
            },
            search: { query in
                let hits = (try? await service.search(query: query)) ?? []
                return hits.map { hit in
                    let target: NavTarget
                    switch hit.scope {
                    case .projects: target = .detail(projectRoute(hit.recordID))
                    case .talks: target = .detail(talkRoute(hit.recordID))
                    case .forms: target = .detail(formRoute(hit.recordID))
                    case .reports: target = .detail(reportRoute(hit.recordID))
                    }
                    return ModuleSearchHit(
                        id: hit.id,
                        group: hit.scope.title,
                        icon: hit.scope.icon,
                        title: hit.title,
                        subtitle: hit.subtitle,
                        target: target
                    )
                }
            }
        )
    }
}
