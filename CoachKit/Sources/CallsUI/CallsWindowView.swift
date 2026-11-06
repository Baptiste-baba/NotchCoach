import CallArchive
import SwiftUI

/// Fenêtre « Calls enregistrés » : la liste des calls à gauche, le call choisi à droite.
public struct CallsWindowView: View {
    public static let windowID = "calls"

    let library: CallLibrary
    @State private var selection: SavedCall.ID?
    /// Gardé d'un call à l'autre : on relit souvent le même onglet de plusieurs calls.
    @State private var tab = CallDetailView.Tab.summary

    public init(library: CallLibrary) {
        self.library = library
    }

    public var body: some View {
        NavigationSplitView {
            CallListView(periods: library.periods, selection: $selection, onDelete: library.delete)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            if let call = library.call(withID: selection) {
                CallDetailView(call: call, tab: $tab, onRetry: { library.retryRecap(of: call) })
            } else if library.periods.isEmpty {
                ContentUnavailableView(
                    "Aucun call enregistré",
                    systemImage: "waveform",
                    description: Text("Chaque call apparaît ici dès que tu l'arrêtes, avec son résumé et son débrief.")
                )
            } else {
                ContentUnavailableView("Choisis un call dans la liste", systemImage: "list.bullet")
            }
        }
        // Remplacé par le titre du call choisi.
        .navigationTitle("Calls enregistrés")
        .tint(CallsStyle.violet)
        .frame(minWidth: 860, minHeight: 540)
        .onAppear {
            library.refresh()
            selectMostRecentIfNeeded()
        }
        .onChange(of: library.periods) {
            selectMostRecentIfNeeded()
        }
        .alert(
            "Suppression impossible",
            isPresented: Binding(get: { library.deletionError != nil }, set: { if !$0 { library.deletionError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(library.deletionError ?? "")
        }
    }

    /// À l'ouverture, ou après la suppression du call choisi : le plus récent.
    private func selectMostRecentIfNeeded() {
        guard library.call(withID: selection) == nil else { return }
        selection = library.periods.first?.calls.first?.id
    }
}
