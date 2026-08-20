import SwiftUI

struct OpportunityDetailView: View {
    let service: SalesSpaceService
    let opportunityID: Int
    @State private var state: LoadState<OpportunityDetail> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let detail):
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(detail.opportunity.name)
                                .font(.title3.weight(.semibold))
                            Text("\(detail.opportunity.number) · \(detail.opportunity.accountName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            StageStepper(stages: SalesStages.ordered, current: detail.opportunity.stage)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 6)
                        .listRowSeparator(.hidden)
                    }

                    Section("Opportunity Details") {
                        ForEach(detail.fields, id: \.label) { field in
                            FieldRow(label: field.label, value: field.value)
                        }
                    }

                    if let contactName = detail.contactName {
                        Section("Primary Contact") {
                            ContactCard(
                                name: contactName,
                                title: detail.contactTitle,
                                phone: detail.contactPhone,
                                email: detail.contactEmail
                            )
                            .padding(.vertical, 4)
                        }
                    }

                    if !detail.revisions.isEmpty {
                        Section("Revisions") {
                            ForEach(detail.revisions) { revision in
                                RecordRow(title: revision.name, subtitle: revision.updated, badge: revision.status)
                            }
                        }
                    }

                    if let notes = detail.notes, !notes.isEmpty {
                        Section("Notes") {
                            Text(notes)
                                .font(.body)
                        }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
            }
        }
        .navigationTitle("Opportunity")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await service.opportunityDetail(id: opportunityID))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
