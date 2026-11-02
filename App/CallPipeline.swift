import Foundation
import NotchUI

/// Relie, pendant un call, la source audio, la transcription des deux canaux, la conversation et la session Claude,
/// et affiche les suggestions dans la notch (étape 5). Remplace `TranscriptionPipeline`.
final class CallPipeline {
    private let replayFile: URL
    private let notch: NotchPanelController

    init(replayFile: URL, notch: NotchPanelController) {
        self.replayFile = replayFile
        self.notch = notch
    }

    /// Prépare les modèles et lance Claude, puis démarre le replay : les suggestions s'affichent dans la notch.
    func start() {
        fatalError("TODO")
    }

    func stop() {
        fatalError("TODO")
    }
}
