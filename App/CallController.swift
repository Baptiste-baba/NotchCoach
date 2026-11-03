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
    /// Repli de la notch prévu après l'échec du démarrage d'un call.
    @ObservationIgnored private var foldTask: Task<Void, Never>?

    init(notch: NotchPanelController, playbookFile: PlaybookFile, replayFile: URL?) {
        self.notch = notch
        self.playbookFile = playbookFile
        self.replayFile = replayFile
    }

    /// Démarre un call : la vraie capture, ou le fichier rejoué depuis le début en mode replay.
    func startCall() {
        guard pipeline == nil else { return }
        // Le message d'échec du call précédent laisse la place au nouveau call.
        foldTask?.cancel()
        let source: any AudioSource = if let replayFile { ReplayAudioSource(file: replayFile) } else { LiveAudioSource() }
        let pipeline = CallPipeline(
            source: source,
            models: models,
            playbookFile: playbookFile,
            coachInstructions: BundledPrompt.text(named: "coach-system")
        )
        self.pipeline = pipeline
        isCallActive = true
        // Une seule tâche : la fin du call, son dernier affichage et le repli de la notch arrivent dans cet ordre.
        Task {
            async let run: Void = pipeline.run()
            var lastDisplay = CoachDisplay.hidden
            for await display in pipeline.displays {
                lastDisplay = display
                show(display)
            }
            await run
            // Call terminé : le menu propose d'en démarrer un autre.
            self.pipeline = nil
            isCallActive = false
            fold(after: lastDisplay)
        }
    }

    /// Arrête le call en cours. Il est terminé quand `run()` revient.
    func stopCall() {
        guard let pipeline else { return }
        Task { await pipeline.stop() }
    }

    /// Replie la notch à la fin d'un call. L'échec de son démarrage reste d'abord lisible, aussi longtemps qu'une
    /// suggestion.
    private func fold(after lastDisplay: CoachDisplay) {
        guard case .error = lastDisplay else {
            notch.display(.empty)
            return
        }
        foldTask = Task {
            try? await Task.sleep(for: ConversationCoordinator.defaultSuggestionLifetime)
            guard !Task.isCancelled else { return }
            notch.display(.empty)
        }
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
