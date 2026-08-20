import Foundation

/// Realistic sample data so every screen is fully navigable before the backend work lands.
struct MockSalesSpaceService: SalesSpaceService {
    static let opportunities: [Opportunity] = [
        Opportunity(id: 1042, number: "OP-1042", name: "Riverside Tower Fit-Out", accountName: "Meridian Property Group", stage: "Proposal", fees: 1_240_000, city: "Toronto"),
        Opportunity(id: 1039, number: "OP-1039", name: "Lakeshore Campus Phase 2", accountName: "Northbridge REIT", stage: "Feasibility", fees: 860_000, city: "Mississauga"),
        Opportunity(id: 1036, number: "OP-1036", name: "King West Office Refresh", accountName: "Stackpole & Partners", stage: "Identified", fees: 320_000, city: "Toronto"),
        Opportunity(id: 1033, number: "OP-1033", name: "Harbourfront Lobby Reno", accountName: "Quayside Holdings", stage: "Negotiation", fees: 540_000, city: "Toronto"),
        Opportunity(id: 1031, number: "OP-1031", name: "Midtown Medical Suites", accountName: "Cedarview Health", stage: "Closed Won", fees: 2_100_000, city: "North York"),
        Opportunity(id: 1027, number: "OP-1027", name: "Gateway Logistics Hub", accountName: "TransCan Freight", stage: "Feasibility", fees: 1_750_000, city: "Brampton"),
        Opportunity(id: 1025, number: "OP-1025", name: "Union Station Retail Pods", accountName: "Metrolinx Commercial", stage: "Proposal", fees: 470_000, city: "Toronto"),
        Opportunity(id: 1022, number: "OP-1022", name: "Bayview Corporate Centre", accountName: "Meridian Property Group", stage: "On Hold", fees: 690_000, city: "Markham"),
    ]

    func dashboard() async throws -> DashboardData {
        DashboardData(
            stats: [
                ("Pipeline", "$8.2M"),
                ("Identified MTD", "$1.4M"),
                ("Closed YTD", "$12.6M"),
                ("Win Rate", "38%"),
            ],
            weeklyIdentified: [
                ("W27", 3), ("W28", 5), ("W29", 2), ("W30", 6),
                ("W31", 4), ("W32", 7), ("W33", 3), ("W34", 5),
            ],
            recent: Array(Self.opportunities.prefix(4))
        )
    }

    func opportunities(query: String, stages: Set<String>) async throws -> [Opportunity] {
        Self.opportunities.filter { opp in
            (query.isEmpty || opp.name.localizedCaseInsensitiveContains(query)
                || opp.accountName.localizedCaseInsensitiveContains(query)
                || opp.number.localizedCaseInsensitiveContains(query))
            && (stages.isEmpty || stages.contains(opp.stage))
        }
    }

    func opportunityDetail(id: Int) async throws -> OpportunityDetail {
        let opp = Self.opportunities.first { $0.id == id } ?? Self.opportunities[0]
        return OpportunityDetail(
            opportunity: opp,
            fields: [
                ("Number", opp.number),
                ("Account", opp.accountName),
                ("Stage", opp.stage),
                ("Est. Fees", opp.feesFormatted),
                ("City", opp.city),
                ("Rep", "Alex Nguyen"),
                ("Source", "Referral"),
                ("Target Close", "Sep 30, 2026"),
            ],
            contactName: "Jordan Blake",
            contactTitle: "Director of Facilities",
            contactPhone: "+1 416 555 0142",
            contactEmail: "jordan.blake@example.com",
            revisions: [
                RevisionSummary(id: "TFR-311", name: "Rev 2 — Full Floor", updated: "Updated 2d ago", status: "Sent"),
                RevisionSummary(id: "TFR-298", name: "Rev 1 — Base Scope", updated: "Updated Jul 22", status: "Approved"),
            ],
            notes: "Client wants phased occupancy starting Q1. Waiting on landlord consent for HVAC upgrade before final pricing."
        )
    }

    func pipeline(scope: String) async throws -> [PipelineGroup] {
        let active = Self.opportunities.filter { $0.stage != "Closed Won" && $0.stage != "On Hold" }
        return SalesStages.ordered.dropLast().map { stage in
            PipelineGroup(label: stage, rows: active.filter { $0.stage == stage })
        }.filter { !$0.rows.isEmpty }
    }

    func records(kind: SalesRecordKind, query: String) async throws -> [RecordItem] {
        let all: [RecordItem]
        switch kind {
        case .accounts:
            all = [
                RecordItem(id: 1, title: "Meridian Property Group", subtitle: "Toronto · 2 open opportunities", trail: "$1.9M"),
                RecordItem(id: 2, title: "Northbridge REIT", subtitle: "Mississauga · 1 open opportunity", trail: "$860K"),
                RecordItem(id: 3, title: "Cedarview Health", subtitle: "North York", trail: "$2.1M"),
                RecordItem(id: 4, title: "TransCan Freight", subtitle: "Brampton", trail: "$1.75M"),
                RecordItem(id: 5, title: "Stackpole & Partners", subtitle: "Toronto", trail: "$320K"),
            ]
        case .contacts:
            all = [
                RecordItem(id: 1, title: "Jordan Blake", subtitle: "Director of Facilities · Meridian", trail: nil),
                RecordItem(id: 2, title: "Priya Raman", subtitle: "VP Real Estate · Northbridge REIT", trail: nil),
                RecordItem(id: 3, title: "Sam Whitfield", subtitle: "COO · Cedarview Health", trail: nil),
                RecordItem(id: 4, title: "Dana Kowalski", subtitle: "Facilities Manager · TransCan", trail: nil),
            ]
        case .buildings:
            all = [
                RecordItem(id: 1, title: "100 Riverside Blvd", subtitle: "Toronto · Class A Office", trail: "12 floors"),
                RecordItem(id: 2, title: "45 Lakeshore Rd E", subtitle: "Mississauga · Campus", trail: "4 bldgs"),
                RecordItem(id: 3, title: "888 King St W", subtitle: "Toronto · Office", trail: "8 floors"),
            ]
        case .revisions:
            all = [
                RecordItem(id: 311, title: "TFR-311 · Rev 2 — Full Floor", subtitle: "Riverside Tower Fit-Out", trail: "Sent"),
                RecordItem(id: 298, title: "TFR-298 · Rev 1 — Base Scope", subtitle: "Riverside Tower Fit-Out", trail: "Approved"),
                RecordItem(id: 287, title: "TFR-287 · Rev 3 — Value Eng", subtitle: "Lakeshore Campus Phase 2", trail: "In Progress"),
            ]
        }
        return query.isEmpty ? all : all.filter {
            $0.title.localizedCaseInsensitiveContains(query) || ($0.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func search(query: String) async throws -> [SearchHit] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }

        var hits = try await opportunities(query: q, stages: []).map { opp in
            SearchHit(
                id: "opportunity-\(opp.id)",
                scope: .opportunities,
                title: opp.name,
                subtitle: "\(opp.number) · \(opp.accountName)",
                opportunity: opp
            )
        }

        for scope in SearchScope.allCases {
            guard let kind = scope.recordKind else { continue }
            let items = try await records(kind: kind, query: q)
            hits += items.map { item in
                SearchHit(
                    id: "\(scope.rawValue)-\(item.id)",
                    scope: scope,
                    title: item.title,
                    subtitle: item.subtitle
                )
            }
        }
        return hits
    }
}
