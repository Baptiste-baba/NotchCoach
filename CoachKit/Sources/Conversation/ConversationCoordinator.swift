import ClaudeSession
import Foundation
import os
import Transcription

/// Étape « Conversation » d'un call : reçoit les segments des deux canaux, décide quand demander une suggestion,
/// l'envoie à la session Claude avec les nouvelles répliques, et tient l'historique du call que la notch affiche.
/// L'appelant démarre la session avant le coordinateur et l'arrête à la fin du call. Le coordinateur ne la relance
/// que si elle a abandonné ses redémarrages automatiques, à la phrase suivante du prospect.
public actor ConversationCoordinator {
    /// Ce que la notch doit afficher : l'historique du call et le message passager du moment. Un seul consommateur.
    public nonisolated let displays: AsyncStream<CallDisplay>

    private let displaysContinuation: AsyncStream<CallDisplay>.Continuation
    private let session: any LLMSession
    /// Instant zéro du call, le même que celui des segments : les mesures de latence s'y rapportent.
    private let callStart: ContinuousClock.Instant

    private var detector = TriggerDetector()
    private var buffer = TranscriptBuffer()
    private var assembler = SuggestionAssembler()
    private var history = CallHistory()
    private var latency = LatencyTracker()
    private var sessionTasks: [Task<Void, Never>] = []
    /// Message d'état passager, sous l'historique : Claude redémarre.
    private var notice: String?
    /// Dernier affichage publié : un changement sans effet visible n'est pas republié.
    private var published = CallDisplay()
    /// Dernier état connu de la session : l'appelant l'a démarrée avant de créer le coordinateur.
    private var sessionState = SessionState.running
    /// Un redémarrage de Claude a vidé sa conversation : toute la transcription repartira au prochain envoi.
    private var needsFullResend = false
    /// De la demande au premier mot affiché, pour Instruments.
    private var suggestionInterval: (requestID: Int, state: OSSignpostIntervalState)?
    private var isStopped = false

    public init(session: any LLMSession, callStart: ContinuousClock.Instant) {
        (displays, displaysContinuation) = AsyncStream.makeStream()
        self.session = session
        self.callStart = callStart
    }

    /// Commence à suivre les réponses et l'état de la session Claude.
    public func start() {
        let events = session.events
        let states = session.states
        sessionTasks.append(Task {
            for await event in events {
                handle(event)
            }
        })
        sessionTasks.append(Task {
            for await state in states {
                handle(state)
            }
        })
    }

    /// Reçoit un segment de l'un ou l'autre canal. Une phrase finale du prospect, hors délai anti-spam, envoie
    /// une demande de suggestion avec les répliques pas encore envoyées.
    public func receive(_ segment: TranscriptSegment) async {
        // Après l'arrêt, plus rien n'est envoyé : Claude ne doit surtout pas être relancé.
        guard !isStopped else { return }
        let receivedAt = callTime()
        buffer.append(segment)
        guard let trigger = detector.receive(segment) else { return }
        if case .failed = sessionState {
            guard await relaunchSession() else { return }
        }
        guard let prompt = buffer.takeUnsent() else { return }
        let requestID = trigger.requestID
        assembler.start(requestID: requestID)
        latency.triggered(requestID: requestID, speechEnd: trigger.segment.end, segmentReceived: receivedAt)
        // Une demande précédente encore sans premier mot est remplacée : son repère s'arrête là.
        endSuggestionInterval()
        suggestionInterval = (requestID, signposter.beginInterval("Suggestion"))
        latency.sent(requestID: requestID, at: callTime())
        await session.send(LLMRequest(id: requestID, prompt: prompt))
    }

    /// Ajoute un échec à l'historique du call, en rouge.
    public func showError(_ message: String) {
        history.addFailure(message)
        publish()
    }

    /// Arrête le suivi de la session et termine le flux d'affichage.
    /// Transcription complète du call, depuis son début.
    public func transcript() -> [TranscriptSegment] {
        fatalError("TODO")
    }

    public func stop() {
        isStopped = true
        sessionTasks.forEach { $0.cancel() }
        sessionTasks = []
        endSuggestionInterval()
        displaysContinuation.finish()
    }

    private func handle(_ event: LLMEvent) {
        switch event {
        case .delta(let requestID, let text):
            // L'ancienne suggestion reste la dernière entrée jusqu'au premier mot montrable de la nouvelle.
            guard let shown = assembler.append(text, requestID: requestID) else { return }
            if let measurement = latency.firstWordShown(requestID: requestID, at: callTime()) {
                report(measurement)
            }
            history.showSuggestion(shown, requestID: requestID)
            publish()
        case .finished(let requestID):
            endSuggestionInterval(requestID: requestID)
            // « - » : rien à suggérer, l'historique ne change pas.
            _ = assembler.finish(requestID: requestID)
        case .failed(let requestID, let message):
            logger.error("Suggestion n°\(requestID, privacy: .public) sans réponse : \(message, privacy: .private)")
            guard assembler.fail(requestID: requestID) else { return }
            endSuggestionInterval(requestID: requestID)
            // Claude redémarre ou est indisponible : son message d'état explique déjà l'absence de réponse.
            guard sessionState == .running else { return }
            let reason = message.trimmingCharacters(in: .whitespacesAndNewlines)
            showError(reason.isEmpty ? "Claude n'a pas pu répondre." : "Claude n'a pas pu répondre : \(reason)")
        }
    }

    private func handle(_ state: SessionState) {
        sessionState = state
        switch state {
        case .restarting:
            needsFullResend = true
            notice = "Claude redémarre…"
        case .failed(let message):
            logger.error("Claude indisponible : \(message, privacy: .public)")
            notice = nil
            history.addFailure("Claude est indisponible. Nouvel essai à la prochaine phrase du prospect.")
        case .running:
            // Le nouveau process est prêt : une demande partie pendant le redémarrage a échoué, tout est renvoyé.
            prepareFullResendIfNeeded()
            // Claude est de retour : son message d'état disparaît.
            notice = nil
        case .stopped:
            break
        }
        publish()
    }

    /// Relance la session après l'abandon de ses redémarrages automatiques. Renvoie faux si elle reste indisponible.
    private func relaunchSession() async -> Bool {
        do {
            try await session.start()
        } catch {
            logger.error("Relance de Claude impossible : \(error.localizedDescription, privacy: .public)")
            return false
        }
        // La conversation du nouveau process est vide : toute la transcription part avec cette demande, sans attendre
        // que l'état `running` soit traité.
        prepareFullResendIfNeeded()
        return true
    }

    private func prepareFullResendIfNeeded() {
        guard needsFullResend else { return }
        buffer.markAllUnsent()
        needsFullResend = false
    }

    /// Publie l'historique et le message passager, s'ils ont changé depuis la dernière publication.
    private func publish() {
        let display = CallDisplay(entries: history.entries, notice: notice)
        guard display != published else { return }
        published = display
        displaysContinuation.yield(display)
    }

    /// Termine le repère Instruments de la demande en cours s'il est encore ouvert : celui de `requestID` seulement,
    /// ou celui de n'importe quelle demande si `requestID` est `nil`.
    private func endSuggestionInterval(requestID: Int? = nil) {
        guard let suggestionInterval, requestID == nil || suggestionInterval.requestID == requestID else { return }
        signposter.endInterval("Suggestion", suggestionInterval.state)
        self.suggestionInterval = nil
    }

    private func report(_ measurement: LatencyMeasurement) {
        endSuggestionInterval(requestID: measurement.requestID)
        logger.info("""
            Suggestion n°\(measurement.requestID, privacy: .public) : \
            fin de tour \(Self.milliseconds(measurement.endOfTurnDetection), privacy: .public) ms, \
            envoi \(Self.milliseconds(measurement.dispatch), privacy: .public) ms, \
            Claude \(Self.milliseconds(measurement.firstWord), privacy: .public) ms, \
            total \(Self.milliseconds(measurement.total), privacy: .public) ms
            """)
    }

    private func callTime() -> TimeInterval {
        (ContinuousClock.now - callStart) / .seconds(1)
    }

    private static func milliseconds(_ seconds: TimeInterval) -> Int {
        Int((seconds * 1000).rounded())
    }
}
