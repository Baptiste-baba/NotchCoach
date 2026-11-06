import Foundation
import os

/// Possède le process `claude` pour toute la durée d'un call : lancement, envoi des requêtes,
/// streaming des réponses, abandon des réponses obsolètes et redémarrage automatique.
public actor ClaudeSession: LLMSession {
    public nonisolated let events: AsyncStream<LLMEvent>
    public nonisolated let states: AsyncStream<SessionState>

    private let eventsContinuation: AsyncStream<LLMEvent>.Continuation
    private let statesContinuation: AsyncStream<SessionState>.Continuation
    private let options: ClaudeSessionOptions
    private let locateBinary: @Sendable (URL?) async throws -> URL
    private let encoder = StreamJSONEncoder()
    private let parser = StreamJSONParser()
    private let backoff: RestartBackoff

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
        self.init(options: options, backoff: RestartBackoff())
    }

    /// Pour les tests : délais de redémarrage réglables, pour ne pas attendre plusieurs secondes, et recherche
    /// du binaire remplaçable, pour maîtriser le moment où un lancement reprend.
    init(
        options: ClaudeSessionOptions,
        backoff: RestartBackoff,
        locateBinary: @escaping @Sendable (URL?) async throws -> URL = { try await ClaudeBinaryLocator().locate(override: $0) }
    ) {
        (events, eventsContinuation) = AsyncStream.makeStream()
        (states, statesContinuation) = AsyncStream.makeStream()
        self.options = options
        self.backoff = backoff
        self.locateBinary = locateBinary
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
        let launchGeneration = generation
        let task = Task { try await launch(generation: launchGeneration) }
        startTask = task
        defer {
            // `stop()` puis un nouveau `start()` ont pu remplacer ce lancement : on n'oublie que le sien.
            if startTask == task {
                startTask = nil
            }
        }
        do {
            try await task.value
        } catch {
            // `stop()` puis un nouveau `start()` ont pu remplacer ce lancement : leur état n'est pas le nôtre.
            if generation == launchGeneration {
                isActive = false
            }
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
        // Un lancement en cours est abandonné : un `start()` qui suit en démarre un nouveau au lieu de l'attendre.
        startTask = nil
        process?.terminate()
        process = nil
        endPendingRequests(failureMessage: nil)
        latestRequestID = nil
        statesContinuation.yield(.stopped)
    }

    /// Lance le process pour la génération en cours au moment de l'appel. Si elle a changé pendant la recherche
    /// du binaire (`stop()`, ou un autre lancement arrivé avant), le process est aussitôt arrêté.
    private func launch(generation launchGeneration: Int) async throws {
        let configuration = ClaudeLaunchConfiguration(
            executableURL: try await locateBinary(options.binaryPathOverride),
            options: options,
            workingDirectory: try ClaudeLaunchConfiguration.makeWorkingDirectory(),
            parentEnvironment: ClaudeLaunchConfiguration.appEnvironment
        )
        let process = try ClaudeProcess(configuration: configuration)
        guard isActive, generation == launchGeneration else {
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
                try await launch(generation: restartGeneration)
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
}
