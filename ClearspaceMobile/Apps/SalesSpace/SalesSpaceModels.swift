import Foundation

// MARK: - sales_space domain models
// Shapes follow the sales_space /api/v1 envelope data; mock data mirrors them.

struct Opportunity: Identifiable, Hashable {
    let id: Int
    let number: String        // e.g. "OP-1042"
    let name: String
    let accountName: String
    let stage: String
    let fees: Double?
    let city: String?

    var feesFormatted: String {
        guard let fees else { return "—" }
        return fees.currencyCompact
    }
}

struct OpportunityDetail {
    let opportunity: Opportunity
    let fields: [(label: String, value: String?)]
    let contactName: String?
    let contactTitle: String?
    let contactPhone: String?
    let contactEmail: String?
    let revisions: [RevisionSummary]
    let notes: String?
}

struct RevisionSummary: Identifiable, Hashable {
    let id: String            // tfr id
    let name: String
    let updated: String
    let status: String
}

/// Generic record for accounts / contacts / buildings lists.
struct RecordItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String?
    let trail: String?
}

struct PipelineGroup: Identifiable {
    var id: String { label }
    let label: String
    let rows: [Opportunity]

    var subtotal: Double { rows.compactMap(\.fees).reduce(0, +) }
}

struct DashboardData {
    let stats: [(label: String, value: String)]
    let weeklyIdentified: [(week: String, count: Double)]
    let recent: [Opportunity]
}

// MARK: - Shared formatting

extension Double {
    /// $1.2M / $340K style compact currency, matching the mockups.
    var currencyCompact: String {
        let absValue = abs(self)
        let sign = self < 0 ? "-" : ""
        switch absValue {
        case 1_000_000...:
            return "\(sign)$\((absValue / 1_000_000).formatted(.number.precision(.fractionLength(0...1))))M"
        case 1_000...:
            return "\(sign)$\((absValue / 1_000).formatted(.number.precision(.fractionLength(0))))K"
        default:
            return "\(sign)$\(absValue.formatted(.number.precision(.fractionLength(0))))"
        }
    }
}

// MARK: - Search

/// The record types the command bar can search.
enum SearchScope: String, CaseIterable, Identifiable {
    case opportunities, accounts, contacts, buildings, revisions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .opportunities: return "Opportunities"
        case .accounts: return "Accounts"
        case .contacts: return "Contacts"
        case .buildings: return "Buildings"
        case .revisions: return "Revisions"
        }
    }

    var icon: String {
        switch self {
        case .opportunities: return "chart.line.uptrend.xyaxis"
        case .accounts: return "building.2"
        case .contacts: return "person"
        case .buildings: return "building"
        case .revisions: return "doc.on.clipboard"
        }
    }

    var recordKind: SalesRecordKind? {
        switch self {
        case .opportunities: return nil
        case .accounts: return .accounts
        case .contacts: return .contacts
        case .buildings: return .buildings
        case .revisions: return .revisions
        }
    }
}

/// One command-bar search result.
struct SearchHit: Identifiable {
    let id: String
    let scope: SearchScope
    let title: String
    var subtitle: String?
    /// Set when the hit is an opportunity, so the palette can open its detail.
    var opportunity: Opportunity?
}

/// Pipeline stages in order (used by the stepper and filters).
/// NOTE: verify against sales_space's canonical stage list when wiring live data.
enum SalesStages {
    static let ordered = ["Identified", "Feasibility", "Proposal", "Negotiation", "Closed Won"]
    static let filterOptions = ordered + ["Closed Lost", "On Hold"]
}
