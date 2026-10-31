import Foundation
import os

private let logger = Logger(subsystem: "io.github.baptiste-baba.NotchCoach", category: "ClaudeSession")
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
    private let backoff = RestartBackoff()

    private var process: ClaudeProcess?
    /// Incrémenté à chaque lancement et à chaque arrêt : la fin de lecture d'un ancien process, ou une boucle
    /// de redémarrage devenue obsolète, est ignorée.
    private var generation = 0
    /// Vrai de `start()` jusqu'à `stop()` ou l'abandon des redémarrages, y compris pendant un redémarrage.
    /// Faux : la mort du process est voulue et ne déclenche pas de redémarrage.
    private var isActive = false
    private var startTask: Task<Void, any Error>?
    private var restartAttempt = 0
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
        // Un second appel pendant un lancement attend ce lancement au lieu d'en démarrer un autre.
        if let startTask {
            return try await startTask.value
        }
        // Déjà lancée, ou redémarrage en cours.
        guard !isActive else { return }
        isActive = true
        restartAttempt = 0
        let task = Task { try await launch() }
        startTask = task
        defer { startTask = nil }
        do {
            try await task.value
        } catch {
            isActive = false
            throw error
        }
    }

    public func send(_ request: LLMRequest) async {
        latestRequestID = request.id
        guard let process else {
            eventsContinuation.yield(.failed(requestID: request.id, message: "Session Claude indisponible"))
            return
        }
        do {
            // Le CLI attendrait la fin de la réponse en cours, désormais obsolète : on l'interrompt.
            if !pendingRequests.isEmpty {
                interruptCount += 1
                try process.write(line: encoder.interruptLine(requestID: "interrupt-\(interruptCount)"))
            }
            try process.write(line: encoder.line(for: request.prompt))
        } catch {
            // Process mort : la fin de sa sortie déclenchera le redémarrage.
            logger.error("Écriture vers claude impossible : \(error.localizedDescription, privacy: .public)")
            eventsContinuation.yield(.failed(requestID: request.id, message: "Session Claude indisponible"))
            return
        }
        let signpostID = signposter.makeSignpostID()
        pendingRequests.append(PendingRequest(
            id: request.id,
            signpostID: signpostID,
            signpostState: signposter.beginInterval("Request", id: signpostID)
        ))
    }

    public func stop() async {
        isActive = false
        generation += 1
        process?.terminate()
        process = nil
        endPendingRequests(failureMessage: nil)
        latestRequestID = nil
        statesContinuation.yield(.stopped)
    }

    private func launch() async throws {
        // Une app lancée hors du terminal peut ne pas avoir ces variables ; le CLI en a besoin.
        var environment = ProcessInfo.processInfo.environment
        environment["USER"] = environment["USER"] ?? NSUserName()
        environment["HOME"] = environment["HOME"] ?? NSHomeDirectory()
        let configuration = ClaudeLaunchConfiguration(
            executableURL: try await locator.locate(override: options.binaryPathOverride),
            options: options,
            workingDirectory: try Self.makeWorkingDirectory(),
            parentEnvironment: environment
        )
        let process = try ClaudeProcess(configuration: configuration)
        guard isActive else {
            // `stop()` appelé pendant le lancement.
            process.terminate()
            return
        }
        generation += 1
        self.process = process
        statesContinuation.yield(.running)
        let lines = process.outputLines
        let generation = generation
        Task { await self.readOutput(lines, generation: generation) }
    }

    private func readOutput(_ lines: AsyncStream<String>, generation: Int) async {
        for await line in lines {
            guard generation == self.generation else { return }
            handle(line)
        }
        guard generation == self.generation, isActive else { return }
        logger.error("Le process claude s'est arrêté")
        process = nil
        endPendingRequests(failureMessage: "Le process Claude s'est arrêté")
        await restart()
    }

    private func restart() async {
        // Un `stop()` (suivi ou non d'un `start()`) pendant l'attente change la génération : la boucle s'arrête.
        let restartGeneration = generation
        while isActive, generation == restartGeneration {
            restartAttempt += 1
            guard restartAttempt <= backoff.maximumAttempts else {
                isActive = false
                statesContinuation.yield(.failed(message: "Claude n'a pas pu redémarrer"))
                return
            }
            statesContinuation.yield(.restarting(attempt: restartAttempt))
            try? await Task.sleep(for: backoff.delay(forAttempt: restartAttempt))
            guard isActive, generation == restartGeneration else { return }
            do {
                try await launch()
                return
            } catch {
                logger.error("Redémarrage de claude impossible : \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func handle(_ line: String) {
        let event: StreamEvent?
        do {
            event = try parser.parse(line)
        } catch {
            logger.error("Ligne stream-json invalide ignorée : \(line, privacy: .private)")
            return
        }
        guard let event, !pendingRequests.isEmpty else { return }
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
            // Une réponse complète prouve que le process est sain : le compteur de redémarrages repart de zéro.
            restartAttempt = 0
            if isLatest {
                eventsContinuation.yield(.finished(requestID: request.id))
            }
        case .failed(let message):
            pendingRequests.removeFirst()
            signposter.endInterval("Request", request.signpostState)
            // Seules les réponses obsolètes sont interrompues : un échec sur la dernière requête est une vraie erreur.
            if isLatest {
                logger.error("Réponse de claude en échec : \(message, privacy: .private)")
                eventsContinuation.yield(.failed(requestID: request.id, message: message))
            }
        }
    }

    /// Termine toutes les requêtes en attente ; avec un message, la plus récente est signalée en échec.
    private func endPendingRequests(failureMessage: String?) {
        for request in pendingRequests {
            signposter.endInterval("Request", request.signpostState)
            if let failureMessage, request.id == latestRequestID {
                eventsContinuation.yield(.failed(requestID: request.id, message: failureMessage))
            }
        }
        pendingRequests.removeAll()
    }

    /// Répertoire de travail dédié et vide du process.
    private static func makeWorkingDirectory() throws -> URL {
        let url = URL.applicationSupportDirectory
            .appending(path: "NotchCoach/ClaudeWorkingDirectory", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
