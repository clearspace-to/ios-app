import Foundation

/// Data source for the sales_space module. Mock is the default until the
/// sales_space backend accepts per-user bearer tokens on /api/v1 (planned backend work).
protocol SalesSpaceService {
    func dashboard() async throws -> DashboardData
    func opportunities(query: String, stages: Set<String>) async throws -> [Opportunity]
    func opportunityDetail(id: Int) async throws -> OpportunityDetail
    func pipeline(scope: String) async throws -> [PipelineGroup]
    func records(kind: SalesRecordKind, query: String) async throws -> [RecordItem]
    /// Cross-record search powering the command bar.
    func search(query: String) async throws -> [SearchHit]
}

enum SalesRecordKind: String, CaseIterable, Identifiable {
    case accounts, contacts, buildings, revisions
    var id: String { rawValue }

    var title: String {
        switch self {
        case .accounts: return "Accounts"
        case .contacts: return "Contacts"
        case .buildings: return "Buildings"
        case .revisions: return "Revisions"
        }
    }

    var icon: String {
        switch self {
        case .accounts: return "building.2"
        case .contacts: return "person.2"
        case .buildings: return "mappin.and.ellipse"
        case .revisions: return "doc.on.doc"
        }
    }
}

/// Live implementation against https://sales.clearspace.to/api/v1.
/// Blocked on backend: /api/v1 must accept `Authorization: Bearer <user JWT>`
/// (dual-auth change in sales_space) before this can be enabled.
struct LiveSalesSpaceService: SalesSpaceService {
    let api: APIClient

    func dashboard() async throws -> DashboardData { throw liveNotReady }
    func opportunities(query: String, stages: Set<String>) async throws -> [Opportunity] { throw liveNotReady }
    func opportunityDetail(id: Int) async throws -> OpportunityDetail { throw liveNotReady }
    func pipeline(scope: String) async throws -> [PipelineGroup] { throw liveNotReady }
    func records(kind: SalesRecordKind, query: String) async throws -> [RecordItem] { throw liveNotReady }
    func search(query: String) async throws -> [SearchHit] { throw liveNotReady }

    private var liveNotReady: Error {
        APIError.server(status: 501, message: "sales_space live API pending bearer-auth backend work")
    }
}
