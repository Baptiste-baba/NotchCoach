import ClaudeSession
import Transcription

/// Étape « Conversation » d'un call : reçoit les segments des deux canaux, décide quand demander une suggestion,
/// l'envoie à la session Claude avec les nouvelles répliques, et décide de ce que la notch affiche.
/// Le démarrage et l'arrêt de la session Claude restent à l'appelant.
public actor ConversationCoordinator {
    /// Ce que la notch doit afficher. Un seul consommateur.
    public nonisolated let displays: AsyncStream<CoachDisplay>

    private let displaysContinuation: AsyncStream<CoachDisplay>.Continuation
    private let session: any LLMSession
    /// Instant zéro du call, le même que celui des segments : les mesures de latence s'y rapportent.
    private let callStart: ContinuousClock.Instant
    /// Durée d'affichage maximale d'une suggestion après la fin de sa réponse.
    private let suggestionLifetime: Duration

    public init(session: any LLMSession, callStart: ContinuousClock.Instant) {
        self.init(session: session, callStart: callStart, suggestionLifetime: .seconds(20))
    }

    /// Pour les tests : durée d'affichage réglable, pour ne pas attendre 20 s.
    init(session: any LLMSession, callStart: ContinuousClock.Instant, suggestionLifetime: Duration) {
        (displays, displaysContinuation) = AsyncStream.makeStream()
        self.session = session
        self.callStart = callStart
        self.suggestionLifetime = suggestionLifetime
    }

    /// Commence à suivre les réponses et l'état de la session Claude.
    public func start() {
        fatalError("TODO")
    }

    /// Reçoit un segment de l'un ou l'autre canal. Une phrase finale du prospect, hors délai anti-spam, envoie
    /// une demande de suggestion avec les répliques pas encore envoyées.
    public func receive(_ segment: TranscriptSegment) async {
        fatalError("TODO")
    }

    /// Arrête le suivi de la session et termine le flux d'affichage.
    public func stop() {
        fatalError("TODO")
    }
}
