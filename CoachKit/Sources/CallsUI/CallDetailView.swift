import CallArchive
import SwiftUI

/// Call choisi : son en-tête, puis trois onglets, Résumé, Débrief et Transcription.
struct CallDetailView: View {
    let call: SavedCall
    /// « Réessayer », quand le compte rendu n'a pas pu être écrit.
    let onRetry: () -> Void

    var body: some View {
        EmptyView()
    }
}
