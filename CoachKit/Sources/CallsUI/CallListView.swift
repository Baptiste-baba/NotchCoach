import CallArchive
import SwiftUI

/// Liste des calls, du plus récent au plus ancien, regroupés par période.
struct CallListView: View {
    let periods: [CallPeriod]
    @Binding var selection: SavedCall.ID?
    /// Clic droit, « Supprimer le call », confirmé.
    let onDelete: (SavedCall) -> Void
    @State private var callToDelete: SavedCall?

    var body: some View {
        List(selection: $selection) {
            ForEach(periods) { period in
                Section(period.title) {
                    ForEach(period.calls) { call in
                        CallRow(call: call)
                            .tag(call.id)
                            .contextMenu {
                                Button("Supprimer le call", role: .destructive) {
                                    callToDelete = call
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Text("Les calls sont gardés 6 mois.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .confirmationDialog(
            "Supprimer ce call ?",
            isPresented: Binding(get: { callToDelete != nil }, set: { if !$0 { callToDelete = nil } }),
            presenting: callToDelete
        ) { call in
            Button("Supprimer", role: .destructive) {
                onDelete(call)
            }
            Button("Annuler", role: .cancel) {}
        } message: { _ in
            Text("Sa transcription, son résumé et son débrief seront effacés.")
        }
    }
}

/// Un call de la liste : son titre, puis son profil, sa durée et son moment.
private struct CallRow: View {
    let call: SavedCall

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(CallFormat.title(of: call))
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(CallFormat.listDetail(of: call, now: Date()))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}
