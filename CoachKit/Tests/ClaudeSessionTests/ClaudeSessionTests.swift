import Foundation
import Testing
@testable import ClaudeSession

/// Session complète contre le faux CLI de `FakeClaude` : aucun appel au vrai `claude`.
struct ClaudeSessionTests {
    let fastBackoff = RestartBackoff(initialDelay: .milliseconds(10), maximumDelay: .milliseconds(20), maximumAttempts: 2)

    func makeSession(script: String = FakeClaude.script) throws -> ClaudeSession {
        ClaudeSession(
            options: ClaudeSessionOptions(systemPrompt: "test", binaryPathOverride: try FakeClaude.install(script)),
            backoff: fastBackoff
        )
    }

    @Test func streamsTheResponseAndIgnoresInvalidLines() async throws {
        let session = try makeSession()
        let (events, reader) = record(session.events)
        defer { reader.cancel() }
        try await session.start()

        await session.send(LLMRequest(id: 1, prompt: "Bonjour"))

        #expect(await eventually { await events.values.count == 3 })
        #expect(await events.values == [
            .delta(requestID: 1, text: "Bon"),
            .delta(requestID: 1, text: "jour"),
            .finished(requestID: 1),
        ])
        await session.stop()
    }

    @Test func onlyTheLatestRequestIsEmitted() async throws {
        let session = try makeSession()
        let (events, reader) = record(session.events)
        defer { reader.cancel() }
        try await session.start()

        await session.send(LLMRequest(id: 1, prompt: "LENT"))
        await session.send(LLMRequest(id: 2, prompt: "Bonjour"))

        #expect(await eventually { await events.values.contains(.finished(requestID: 2)) })
        #expect(await events.values == [
            .delta(requestID: 2, text: "Bon"),
            .delta(requestID: 2, text: "jour"),
            .finished(requestID: 2),
        ])
        await session.stop()
    }

    @Test func cliErrorFailsTheRequest() async throws {
        let session = try makeSession()
        let (events, reader) = record(session.events)
        defer { reader.cancel() }
        try await session.start()

        await session.send(LLMRequest(id: 7, prompt: "ERREUR"))

        #expect(await eventually { await events.values == [.failed(requestID: 7, message: "Not logged in")] })
        await session.stop()
    }

    @Test func sendBeforeStartFails() async throws {
        let session = try makeSession()
        let (events, reader) = record(session.events)
        defer { reader.cancel() }

        await session.send(LLMRequest(id: 1, prompt: "Bonjour"))

        #expect(await eventually { await events.values == [.failed(requestID: 1, message: "Session Claude indisponible")] })
    }

    @Test func restartsAfterTheProcessDiesAndAnswersAgain() async throws {
        let session = try makeSession()
        let (events, eventsReader) = record(session.events)
        let (states, statesReader) = record(session.states)
        defer {
            eventsReader.cancel()
            statesReader.cancel()
        }
        try await session.start()

        await session.send(LLMRequest(id: 1, prompt: "MEURS"))

        #expect(await eventually { await states.values == [.running, .restarting(attempt: 1), .running] })
        #expect(await events.values == [.failed(requestID: 1, message: "Le process Claude s'est arrêté")])

        await session.send(LLMRequest(id: 2, prompt: "Bonjour"))

        #expect(await eventually { await events.values.last == .finished(requestID: 2) })
        await session.stop()
    }

    @Test func givesUpAfterTheMaximumNumberOfRestarts() async throws {
        let session = try makeSession(script: FakeClaude.dyingScript)
        let (states, reader) = record(session.states)
        defer { reader.cancel() }

        try await session.start()

        #expect(await eventually { await states.values.last == .failed(message: "Claude n'a pas pu redémarrer") })
        #expect(await states.values == [
            .running, .restarting(attempt: 1),
            .running, .restarting(attempt: 2),
            .running, .failed(message: "Claude n'a pas pu redémarrer"),
        ])
    }

    @Test func stopDoesNotTriggerARestart() async throws {
        let session = try makeSession()
        let (states, reader) = record(session.states)
        defer { reader.cancel() }
        try await session.start()

        await session.stop()
        try await Task.sleep(for: .milliseconds(300))

        #expect(await states.values == [.running, .stopped])
    }

    @Test func concurrentStartsLaunchASingleProcess() async throws {
        let session = try makeSession()
        let (states, reader) = record(session.states)
        defer { reader.cancel() }

        async let first: Void = session.start()
        async let second: Void = session.start()
        _ = try await (first, second)
        try await Task.sleep(for: .milliseconds(100))

        #expect(await states.values == [.running])
        await session.stop()
    }

    @Test func nonExecutableOverrideFailsToStart() async throws {
        let session = ClaudeSession(options: ClaudeSessionOptions(
            systemPrompt: "test",
            binaryPathOverride: URL(filePath: "/etc/hosts")
        ))

        await #expect(throws: ClaudeSessionError.binaryNotExecutable(path: "/etc/hosts")) {
            try await session.start()
        }
    }
}
