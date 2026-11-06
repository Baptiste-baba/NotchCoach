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
    /// Fournit le profil actif au démarrage de chaque call.
    @ObservationIgnored private let profiles: ProfileController
    /// Fichier rejoué à la place de la vraie capture, à chaque call ; `nil` hors mode replay.
    @ObservationIgnored private let replayFile: URL?
    /// Gardés d'un call à l'autre : seul le premier call charge les modèles.
    @ObservationIgnored private let models = ParakeetModels()
    @ObservationIgnored private var pipeline: CallPipeline?

    init(notch: NotchPanelController, profiles: ProfileController, replayFile: URL?) {
        self.notch = notch
        self.profiles = profiles
        self.replayFile = replayFile
    }

    /// Démarre un call avec le profil actif : la vraie capture, ou le fichier rejoué depuis le début en mode replay.
    func startCall() {
        guard pipeline == nil else { return }
        guard let profile = profiles.requireActiveProfile() else { return }
        let source: any AudioSource = if let replayFile { ReplayAudioSource(file: replayFile) } else { LiveAudioSource() }
        let pipeline = CallPipeline(
            source: source,
            models: models,
            profile: profile,
            coachFrame: BundledPrompt.text(named: "coach-frame")
        )
        self.pipeline = pipeline
        isCallActive = true
        // Une seule tâche : le call n'est terminé pour le menu qu'après son dernier affichage.
        Task {
            async let run: Void = pipeline.run()
            for await display in pipeline.displays {
                show(display)
            }
            await run
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

    private func show(_ display: CallDisplay) {
        notch.display(NotchContent(
            lines: display.entries.map { NotchContent.Line(id: $0.id, text: $0.text, isError: $0.kind == .failure) },
            notice: display.notice
        ))
    }
}
