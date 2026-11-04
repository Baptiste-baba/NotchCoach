import AudioCapture
import ClaudeSession
import Conversation
import Prompting
import Transcription

/// Relie, pendant un call, la source audio, la transcription des deux canaux, la conversation, le playbook et la
/// session Claude, et publie ce que la notch affiche. Un pipeline ne sert qu'à un call.
public actor CallPipeline {
    /// Ce que la notch doit afficher, du démarrage à la fin du call. Un seul consommateur. Le flux se termine avec
    /// le call, toujours sur une notch repliée.
    public nonisolated let displays: AsyncStream<CallDisplay>

    private let displaysContinuation: AsyncStream<CallDisplay>.Continuation
    private let source: any AudioSource
    private let models: ParakeetModels
    private let playbookFile: PlaybookFile
    private let coachInstructions: String
    private var session: ClaudeSession?
    private var coordinator: ConversationCoordinator?
    /// Affichage de l'échec du démarrage, que `stop()` interrompt.
    private var startFailureDisplay: Task<Void, Never>?
    private var isStopped = false

    /// `models` peut servir d'un call à l'autre : seul le premier les charge. `coachInstructions` : consignes du coach,
    /// avec l'emplacement du playbook.
    public init(source: any AudioSource, models: ParakeetModels, playbookFile: PlaybookFile, coachInstructions: String) {
        (displays, displaysContinuation) = AsyncStream.makeStream()
        self.source = source
        self.models = models
        self.playbookFile = playbookFile
        self.coachInstructions = coachInstructions
    }

    /// Déroule le call : lit le playbook, prépare les modèles et lance Claude, puis transcrit la source et suggère
    /// des réponses. Revient à la fin du call : source terminée et dernière suggestion repliée, appel à `stop()`, ou
    /// démarrage impossible, une fois son message replié.
    public func run() async {
        defer {
            displaysContinuation.yield(CallDisplay())
            displaysContinuation.finish()
        }
        // Lu à chaque call : une modification du playbook compte dès le call suivant. Inutilisable, il est ignoré
        // plutôt que de priver le call de suggestions.
        var playbook = Playbook(markdown: "")
        var playbookError: PromptingError?
        do {
            playbook = try playbookFile.load()
        } catch {
            playbookError = error
        }
        let systemPrompt = SystemPrompt.text(instructions: coachInstructions, playbook: playbook)
        let session = ClaudeSession(options: ClaudeSessionOptions(systemPrompt: systemPrompt))
        self.session = session
        do {
            for try await state in models.prepare() {
                guard !isStopped else { return }
                displaysContinuation.yield(CallDisplay(notice: Self.message(for: state)))
            }
            guard !isStopped else { return }
            // Le process `claude` est lancé avant l'audio : il est déjà chaud à la première suggestion.
            displaysContinuation.yield(CallDisplay(notice: "Lancement de Claude…"))
            try await session.start()
        } catch {
            // Un arrêt pendant le lancement de Claude le fait échouer : ce n'est pas une erreur à montrer.
            guard !isStopped else { return }
            await showStartFailure(error)
            return
        }
        guard !isStopped else { return }
        displaysContinuation.yield(CallDisplay())

        // Instant zéro du call, pris juste avant la source : celui des segments, auquel se rapporte la latence.
        let coordinator = ConversationCoordinator(session: session, callStart: .now)
        self.coordinator = coordinator
        await coordinator.start()
        let forwarding = Task { [displaysContinuation] in
            for await display in coordinator.displays {
                displaysContinuation.yield(display)
            }
        }
        if let playbookError {
            await coordinator.showError("Call sans playbook. \(playbookError.localizedDescription)")
        }
        // Une capture coupée que sa relance n'a pas réparée, en plein call : la notch le dit en rouge.
        let failureReports = Task {
            for await failure in source.failures {
                await coordinator.showError(failure.localizedDescription)
            }
        }
        let transcriptions = Speaker.allCases.map { speaker in
            let segments = ParakeetEngine(speaker: speaker, models: models).transcribe(source.chunks(of: speaker))
            return Task {
                for await segment in segments {
                    await coordinator.receive(segment)
                }
            }
        }
        do {
            try await source.start()
        } catch {
            // Sans audio, pas de call : la source s'arrête, et le call se termine une fois le message d'échec replié.
            await source.stop()
            await coordinator.showError(error.localizedDescription)
        }
        // Les flux de transcription se terminent avec la source : fin du fichier rejoué, ou arrêt.
        for transcription in transcriptions {
            await transcription.value
        }
        await failureReports.value
        // Rien n'est perdu : la dernière suggestion arrive et se replie. Après un arrêt, revient tout de suite.
        await coordinator.finish()
        await forwarding.value
        await session.stop()
    }

    /// Arrête le call tout de suite : la source, la conversation et Claude.
    public func stop() async {
        guard !isStopped else { return }
        isStopped = true
        startFailureDisplay?.cancel()
        await source.stop()
        await coordinator?.stop()
        await session?.stop()
    }

    /// Démarrage impossible : le message reste lisible aussi longtemps qu'une suggestion, sauf arrêt.
    private func showStartFailure(_ error: any Error) async {
        displaysContinuation.yield(CallDisplay(entries: [.init(id: 0, kind: .failure, text: error.localizedDescription)]))
        let display = Task {
            _ = try? await Task.sleep(for: ConversationCoordinator.defaultSuggestionLifetime)
        }
        startFailureDisplay = display
        await display.value
    }

    private static func message(for state: ModelLoadState) -> String {
        switch state {
        case .downloading(let fraction):
            "Téléchargement des modèles de transcription : \(Int(fraction * 100)) %"
        case .loading:
            "Chargement des modèles de transcription…"
        }
    }
}
