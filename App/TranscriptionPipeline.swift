import AudioCapture
import Foundation
import NotchUI
import Transcription

/// Relie une source audio aux moteurs de transcription des deux canaux et affiche la transcription brute
/// dans la notch (étape 3).
final class TranscriptionPipeline {
    private let source: ReplayAudioSource
    private let models = ParakeetModels()
    private let notch: NotchPanelController

    init(replayFile: URL, notch: NotchPanelController) {
        source = ReplayAudioSource(file: replayFile)
        self.notch = notch
    }

    /// Prépare les modèles (avancement affiché dans la notch), puis lance la transcription des deux canaux
    /// et la lecture du fichier.
    func start() {
        fatalError("TODO")
    }

    func stop() {
        fatalError("TODO")
    }
}
