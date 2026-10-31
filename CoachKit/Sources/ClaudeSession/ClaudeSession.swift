/// Possède le process `claude` pour toute la durée d'un call : lancement, envoi des requêtes,
/// streaming des réponses, abandon des réponses obsolètes et redémarrage automatique.
public actor ClaudeSession: LLMSession {
    public nonisolated let events: AsyncStream<LLMEvent>
    public nonisolated let states: AsyncStream<SessionState>

    private let eventsContinuation: AsyncStream<LLMEvent>.Continuation
    private let statesContinuation: AsyncStream<SessionState>.Continuation
    private let options: ClaudeSessionOptions

    public init(options: ClaudeSessionOptions) {
        (events, eventsContinuation) = AsyncStream.makeStream()
        (states, statesContinuation) = AsyncStream.makeStream()
        self.options = options
    }

    public func start() async throws {
        fatalError("TODO")
    }

    public func send(_ request: LLMRequest) async {
        fatalError("TODO")
    }

    public func stop() async {
        fatalError("TODO")
    }
}
