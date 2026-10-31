/// Session de génération de suggestions. Implémentée par `ClaudeSession`, et par un mock dans les tests.
public protocol LLMSession: Actor {
    /// Réponses, uniquement pour la requête la plus récente. Un seul consommateur.
    nonisolated var events: AsyncStream<LLMEvent> { get }
    /// Changements d'état de la session. Un seul consommateur.
    nonisolated var states: AsyncStream<SessionState> { get }

    /// Lance la session ; elle reste vivante jusqu'à `stop()`.
    func start() async throws
    /// Envoie une requête. Toute réponse en cours pour une requête plus ancienne devient obsolète.
    func send(_ request: LLMRequest) async
    /// Arrête la session et son process.
    func stop() async
}
