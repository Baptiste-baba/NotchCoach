import CallArchive
import SwiftUI

/// Liste des calls, du plus récent au plus ancien, regroupés par période.
struct CallListView: View {
    let periods: [CallPeriod]
    @Binding var selection: SavedCall.ID?
    /// Clic droit, « Supprimer le call », confirmé.
    let onDelete: (SavedCall) -> Void

    var body: some View {
        EmptyView()
    }
}
