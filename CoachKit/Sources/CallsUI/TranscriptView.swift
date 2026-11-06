import CallArchive
import Foundation
import SwiftUI

/// Transcription d'un call, en script : l'heure, qui parle, le texte.
struct TranscriptView: View {
    let lines: [SavedCall.Line]
    /// Moment ouvert depuis le débrief, en secondes : la réplique correspondante est montrée et surlignée.
    let highlightedMoment: TimeInterval?

    var body: some View {
        EmptyView()
    }
}
