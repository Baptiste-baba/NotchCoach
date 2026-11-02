import AudioCapture
import Foundation
import NotchUI
import Transcription

/// Relie une source audio aux moteurs de transcription des deux canaux et affiche la transcription brute
/// dans la notch (étape 3).
final class TranscriptionPipeline {
    /// Nombre de prises de parole visibles : la zone dépliée tient environ trois lignes.
    private static let visibleSegmentCount = 2

    private let source: ReplayAudioSource
    private let models = ParakeetModels()
    private let notch: NotchPanelController
    private var tasks: [Task<Void, Never>] = []
    private var lines: [String] = []
    private var modelsSettled = false

    init(replayFile: URL, notch: NotchPanelController) {
        source = ReplayAudioSource(file: replayFile)
        self.notch = notch
    }

    /// Prépare les modèles (avancement affiché dans la notch), puis lance la transcription des deux canaux
    /// et la lecture du fichier.
    func start() {
        tasks.append(Task {
            for await state in models.loadStates {
                show(state)
            }
        })
        tasks.append(Task { await run() })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
        Task { await source.stop() }
    }

    private func run() async {
        do {
            try await models.prepare()
            modelsSettled = true
        } catch {
            modelsSettled = true
            notch.display(.text(error.localizedDescription))
            return
        }
        notch.display(.text("Écoute…"))
        for speaker in Speaker.allCases {
            let segments = ParakeetEngine(speaker: speaker, models: models).transcribe(source.chunks(of: speaker))
            tasks.append(Task {
                for await segment in segments {
                    show(segment)
                }
            })
        }
        do {
            try await source.start()
        } catch {
            notch.display(.text(error.localizedDescription))
            // Termine les flux audio : les moteurs s'arrêtent au lieu d'attendre indéfiniment.
            await source.stop()
        }
    }

    private func show(_ state: ModelLoadState) {
        // Un avancement encore en file ne doit pas écraser le message affiché après la préparation.
        guard !modelsSettled else { return }
        switch state {
        case .downloading(let fraction):
            notch.display(.text("Téléchargement des modèles de transcription : \(Int(fraction * 100)) %"))
        case .loading:
            notch.display(.text("Chargement des modèles de transcription…"))
        case .ready:
            break
        }
    }

    private func show(_ segment: TranscriptSegment) {
        let name = segment.speaker == .me ? "Moi" : "Prospect"
        lines.append("\(name) : \(segment.text)")
        lines = Array(lines.suffix(Self.visibleSegmentCount))
        notch.display(.text(lines.joined(separator: "\n")))
    }
}
