import AudioCapture
import CallArchive
import ClaudeSession
import Conversation
import Prompting
import Transcription

/// Relie, pendant un call, la source audio, la transcription des deux canaux, la conversation, le playbook et la
/// session Claude, et publie ce que la notch affiche. Un pipeline ne sert qu'à un call.
public actor CallPipeline {
    /// Durée d'affichage d'un échec du démarrage, avant la fin du call.
    private static let startFailureLifetime = Duration.seconds(20)

    /// Ce que la notch doit afficher, du démarrage à la fin du call. Un seul consommateur. Le flux se termine avec
    /// le call, toujours sur une notch repliée.
    public nonisolated let displays: AsyncStream<CallDisplay>

    private let displaysContinuation: AsyncStream<CallDisplay>.Continuation
    private let source: any AudioSource
    private let models: ParakeetModels
    private let profile: Profile
    /// Partie technique du system prompt, fournie par l'app, avec les emplacements du prompt et du playbook du profil.
    private let coachFrame: String
    private var session: ClaudeSession?
    private var coordinator: ConversationCoordinator?
    /// Affichage de l'échec du démarrage, que `stop()` interrompt.
    private var startFailureDisplay: Task<Void, Never>?
    /// `run()` attend ici l'arrêt, une fois la source terminée.
    private var stopWaiter: CheckedContinuation<Void, Never>?
    private var isStopped = false

    /// `models` peut servir d'un call à l'autre : seul le premier les charge. `profile` : profil actif au démarrage du
    /// call. `coachFrame` : partie technique du system prompt, avec les emplacements `{{prompt}}` et `{{playbook}}`.
    public init(source: any AudioSource, models: ParakeetModels, profile: Profile, coachFrame: String) {
        (displays, displaysContinuation) = AsyncStream.makeStream()
        self.source = source
        self.models = models
        self.profile = profile
        self.coachFrame = coachFrame
    }

    /// Déroule le call : lit le playbook, prépare les modèles et lance Claude, puis transcrit la source et suggère
    /// des réponses. Revient à la fin du call : appel à `stop()`, ou démarrage impossible, une fois son message replié.
    /// Un replay continue après la fin du fichier, notch dépliée avec tout son historique, jusqu'à l'arrêt.
    public func run() async {
        defer {
            displaysContinuation.yield(CallDisplay())
            displaysContinuation.finish()
        }
        // Prompt et playbook sont lus à chaque call : une modification compte dès le call suivant. Sans son prompt,
        // Claude ne saurait pas quel rôle jouer : le call ne démarre pas.
        let prompt: String
        do {
            prompt = try profile.loadPrompt()
        } catch {
            await showStartFailure(error)
            return
        }
        // Un playbook inutilisable est ignoré plutôt que de priver le call de suggestions.
        var playbook = Playbook(markdown: "")
        var playbookError: PromptingError?
        do {
            playbook = try profile.playbookFile.load()
        } catch {
            playbookError = error
        }
        let systemPrompt = SystemPrompt.text(frame: coachFrame, prompt: prompt, playbook: playbook)
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
            // Sans audio, pas de call : la conversation s'arrête, et le call se termine une fois l'échec lu.
            await source.stop()
            await coordinator.stop()
            await forwarding.value
            await showStartFailure(error)
            await session.stop()
            return
        }
        // Les flux de transcription se terminent avec la source : fin du fichier rejoué, ou arrêt.
        for transcription in transcriptions {
            await transcription.value
        }
        await failureReports.value
        await waitUntilStopped()
        await forwarding.value
        await session.stop()
    }

    /// Call à enregistrer, une fois `run()` revenu : sa transcription et le profil utilisé. `nil` si personne n'a
    /// parlé, ou si le call n'a pas pu démarrer.
    public func savedCall() async -> SavedCall? {
        fatalError("TODO")
    }

    /// Arrête le call tout de suite : la source, la conversation et Claude.
    public func stop() async {
        guard !isStopped else { return }
        isStopped = true
        startFailureDisplay?.cancel()
        stopWaiter?.resume()
        stopWaiter = nil
        await source.stop()
        await coordinator?.stop()
        await session?.stop()
    }

    /// Démarrage impossible : le message reste lisible aussi longtemps qu'une suggestion, sauf arrêt.
    private func showStartFailure(_ error: any Error) async {
        displaysContinuation.yield(CallDisplay(entries: [.init(id: 0, kind: .failure, text: error.localizedDescription)]))
        let display = Task {
            _ = try? await Task.sleep(for: Self.startFailureLifetime)
        }
        startFailureDisplay = display
        await display.value
    }

    private func waitUntilStopped() async {
        guard !isStopped else { return }
        await withCheckedContinuation { stopWaiter = $0 }
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
