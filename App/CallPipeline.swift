import AudioCapture
import ClaudeSession
import Conversation
import Foundation
import NotchUI
import Prompting
import Transcription

/// Relie, pendant un call, la source audio, la transcription des deux canaux, la conversation et la session Claude,
/// et affiche les suggestions dans la notch (étape 5).
final class CallPipeline {
    private let source: ReplayAudioSource
    private let playbookFile: PlaybookFile
    private let models = ParakeetModels()
    private let notch: NotchPanelController
    private var session: ClaudeSession?
    private var coordinator: ConversationCoordinator?
    private var tasks: [Task<Void, Never>] = []

    init(replayFile: URL, playbookFile: PlaybookFile, notch: NotchPanelController) {
        source = ReplayAudioSource(file: replayFile)
        self.playbookFile = playbookFile
        self.notch = notch
    }

    /// Lit le playbook, prépare les modèles et lance Claude, puis démarre le replay : les suggestions s'affichent
    /// dans la notch.
    func start() {
        tasks.append(Task { await run() })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
        Task { [source, coordinator, session] in
            await source.stop()
            await coordinator?.stop()
            await session?.stop()
        }
    }

    private func run() async {
        let session: ClaudeSession
        do {
            // Lu à chaque call : une modification du playbook compte dès le call suivant.
            let instructions = BundledPrompt.text(named: "coach-system")
            let systemPrompt = SystemPrompt.text(instructions: instructions, playbook: try playbookFile.load())
            session = ClaudeSession(options: ClaudeSessionOptions(systemPrompt: systemPrompt))
            self.session = session
            for try await state in models.prepare() {
                show(state)
            }
            // Le process `claude` est lancé avant l'audio : il est déjà chaud à la première suggestion.
            notch.display(.text("Lancement de Claude…"))
            try await session.start()
        } catch {
            notch.display(.error(error.localizedDescription))
            return
        }
        guard !Task.isCancelled else { return }
        notch.display(.empty)

        // Instant zéro du call, pris juste avant le replay : celui des segments, auquel se rapporte la latence.
        let coordinator = ConversationCoordinator(session: session, callStart: .now)
        self.coordinator = coordinator
        await coordinator.start()
        tasks.append(Task {
            for await display in coordinator.displays {
                show(display)
            }
        })
        for speaker in Speaker.allCases {
            let segments = ParakeetEngine(speaker: speaker, models: models).transcribe(source.chunks(of: speaker))
            tasks.append(Task {
                for await segment in segments {
                    await coordinator.receive(segment)
                }
            })
        }
        do {
            try await source.start()
        } catch {
            notch.display(.error(error.localizedDescription))
            // Sans audio, pas de call : la source, la conversation et Claude s'arrêtent.
            stop()
        }
    }

    private func show(_ state: ModelLoadState) {
        switch state {
        case .downloading(let fraction):
            notch.display(.text("Téléchargement des modèles de transcription : \(Int(fraction * 100)) %"))
        case .loading:
            notch.display(.text("Chargement des modèles de transcription…"))
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
