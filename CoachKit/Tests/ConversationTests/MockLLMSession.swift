import ClaudeSession

/// Fausse session Claude : enregistre les demandes et les lancements, et émet les réponses et les états que le test
/// lui dicte. Contrairement à `ClaudeSession`, `start()` n'émet pas `running` : le test choisit quand.
actor MockLLMSession: LLMSession {
    struct LaunchFailure: Error {}

    nonisolated let events: AsyncStream<LLMEvent>
    nonisolated let states: AsyncStream<SessionState>

    private let eventsContinuation: AsyncStream<LLMEvent>.Continuation
    private let statesContinuation: AsyncStream<SessionState>.Continuation
    private(set) var requests: [LLMRequest] = []
    private(set) var startCount = 0
    /// Vrai : les lancements échouent.
    private var startFails = false

    init() {
        (events, eventsContinuation) = AsyncStream.makeStream()
        (states, statesContinuation) = AsyncStream.makeStream()
    }

    func start() async throws {
        startCount += 1
        if startFails {
            throw LaunchFailure()
        }
    }

    func send(_ request: LLMRequest) async {
        requests.append(request)
    }

    func stop() async {}

    func setStartFails(_ fails: Bool) {
        startFails = fails
    }

    nonisolated func emit(_ event: LLMEvent) {
        eventsContinuation.yield(event)
    }

    nonisolated func emit(_ state: SessionState) {
        statesContinuation.yield(state)
    }
}
