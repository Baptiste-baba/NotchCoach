import AudioCapture
import Call
import Conversation
import Foundation
import NotchUI
import Observation
import Prompting
import Transcription

/// Démarre et arrête les calls depuis le menu, et affiche dans la notch ce que publie le call en cours.
@Observable
final class CallController {
    /// Un call est en cours, de son démarrage à sa fin : le menu propose de l'arrêter.
    private(set) var isCallActive = false

    @ObservationIgnored private let notch: NotchPanelController
    @ObservationIgnored private let playbookFile: PlaybookFile
    /// Fichier rejoué à la place de la vraie capture, à chaque call ; `nil` hors mode replay.
    @ObservationIgnored private let replayFile: URL?
    /// Gardés d'un call à l'autre : seul le premier call charge les modèles.
    @ObservationIgnored private let models = ParakeetModels()
    @ObservationIgnored private var pipeline: CallPipeline?

    init(notch: NotchPanelController, playbookFile: PlaybookFile, replayFile: URL?) {
        self.notch = notch
        self.playbookFile = playbookFile
        self.replayFile = replayFile
    }

    /// Démarre un call : la vraie capture, ou le fichier rejoué depuis le début en mode replay.
    func startCall() {
        guard pipeline == nil else { return }
        let source: any AudioSource = if let replayFile { ReplayAudioSource(file: replayFile) } else { LiveAudioSource() }
        let pipeline = CallPipeline(
            source: source,
            models: models,
            playbookFile: playbookFile,
            coachInstructions: BundledPrompt.text(named: "coach-system")
        )
        self.pipeline = pipeline
        isCallActive = true
        Task {
            for await display in pipeline.displays {
                show(display)
            }
            // Call terminé, après son dernier affichage : la notch se replie.
            notch.display(.empty)
        }
        Task {
            await pipeline.run()
            // Call terminé : le menu propose d'en démarrer un autre.
            self.pipeline = nil
            isCallActive = false
        }
    }

    /// Arrête le call en cours. Il est terminé quand `run()` revient.
    func stopCall() {
        guard let pipeline else { return }
        Task { await pipeline.stop() }
    }

    private func show(_ display: CoachDisplay) {
        switch display {
        case .hidden:
            notch.display(.empty)
        case .suggestion(let text), .notice(let text):
            notch.display(.text(text))
        case .error(let text):
            notch.display(.error(text))
        }
    }
}
