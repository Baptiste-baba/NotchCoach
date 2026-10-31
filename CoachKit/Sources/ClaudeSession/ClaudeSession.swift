import Foundation
import os

private let signposter = OSSignposter(subsystem: "io.github.baptiste-baba.NotchCoach", category: "ClaudeSession")

/// Possède le process `claude` pour toute la durée d'un call : lancement, envoi des requêtes,
/// streaming des réponses, abandon des réponses obsolètes et redémarrage automatique.
public actor ClaudeSession: LLMSession {
    public nonisolated let events: AsyncStream<LLMEvent>
    public nonisolated let states: AsyncStream<SessionState>

    private let eventsContinuation: AsyncStream<LLMEvent>.Continuation
    private let statesContinuation: AsyncStream<SessionState>.Continuation
    private let options: ClaudeSessionOptions
    private let locator = ClaudeBinaryLocator()
    private let encoder = StreamJSONEncoder()
    private let parser = StreamJSONParser()

    private var process: ClaudeProcess?
    /// Requêtes envoyées dont la réponse n'est pas terminée, dans l'ordre d'envoi : le CLI les traite une par une,
    /// et chaque ligne `result` termine la plus ancienne.
    private var pendingRequests: [PendingRequest] = []
    /// Seule la réponse à cette requête est émise : les autres sont obsolètes.
    private var latestRequestID: Int?
    private var interruptCount = 0

    private struct PendingRequest {
        let id: Int
        let signpostID: OSSignpostID
        let signpostState: OSSignpostIntervalState
        var hasReceivedText = false
    }

    public init(options: ClaudeSessionOptions) {
        (events, eventsContinuation) = AsyncStream.makeStream()
        (states, statesContinuation) = AsyncStream.makeStream()
        self.options = options
    }

    public func start() async throws {
        guard process == nil else { return }
        let configuration = ClaudeLaunchConfiguration(
            executableURL: try await locator.locate(override: options.binaryPathOverride),
            options: options,
            workingDirectory: try Self.makeWorkingDirectory(),
            parentEnvironment: ProcessInfo.processInfo.environment
        )
        let process = try ClaudeProcess(configuration: configuration)
        self.process = process
        statesContinuation.yield(.running)
        let lines = process.outputLines
        Task { await self.readOutput(lines) }
    }

    public func send(_ request: LLMRequest) async {
        guard let process else { return }
        latestRequestID = request.id
        do {
            // Le CLI attendrait la fin de la réponse en cours, désormais obsolète : on l'interrompt.
            if !pendingRequests.isEmpty {
                interruptCount += 1
                try process.write(line: encoder.interruptLine(requestID: "interrupt-\(interruptCount)"))
            }
            try process.write(line: encoder.line(for: request.prompt))
            let signpostID = signposter.makeSignpostID()
            pendingRequests.append(PendingRequest(
                id: request.id,
                signpostID: signpostID,
                signpostState: signposter.beginInterval("Request", id: signpostID)
            ))
        } catch {
            // Échec d'écriture : traité à la couche Erreurs.
        }
    }

    public func stop() async {
        process?.terminate()
        process = nil
        pendingRequests.removeAll()
        latestRequestID = nil
        statesContinuation.yield(.stopped)
    }

    private func readOutput(_ lines: AsyncStream<String>) async {
        for await line in lines {
            handle(line)
        }
    }

    private func handle(_ line: String) {
        guard let event = try? parser.parse(line), !pendingRequests.isEmpty else { return }
        let request = pendingRequests[0]
        let isLatest = request.id == latestRequestID
        switch event {
        case .textDelta(let text):
            if !request.hasReceivedText {
                pendingRequests[0].hasReceivedText = true
                signposter.emitEvent("First token", id: request.signpostID)
            }
            if isLatest {
                eventsContinuation.yield(.delta(requestID: request.id, text: text))
            }
        case .completed:
            pendingRequests.removeFirst()
            signposter.endInterval("Request", request.signpostState)
            if isLatest {
                eventsContinuation.yield(.finished(requestID: request.id))
            }
        case .failed:
            // Réponse interrompue parce qu'obsolète ; les vrais échecs sont traités à la couche Erreurs.
            pendingRequests.removeFirst()
            signposter.endInterval("Request", request.signpostState)
        }
    }

    /// Répertoire de travail dédié et vide du process.
    private static func makeWorkingDirectory() throws -> URL {
        let url = URL.applicationSupportDirectory
            .appending(path: "NotchCoach/ClaudeWorkingDirectory", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
