import ClaudeSession
import Foundation
import os
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

    private var detector = TriggerDetector()
    private var buffer = TranscriptBuffer()
    private var assembler = SuggestionAssembler()
    private var latency = LatencyTracker()
    private var sessionTasks: [Task<Void, Never>] = []
    private var hideTask: Task<Void, Never>?
    /// Un redémarrage de Claude a vidé sa conversation : toute la transcription repartira au prochain envoi.
    private var needsFullResend = false
    /// De la demande au premier mot affiché, pour Instruments.
    private var suggestionInterval: (requestID: Int, state: OSSignpostIntervalState)?

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
        let receivedAt = callTime()
        buffer.append(segment)
        guard let trigger = detector.receive(segment), let prompt = buffer.takeUnsent() else { return }
        let requestID = trigger.requestID
        assembler.start(requestID: requestID)
        latency.triggered(requestID: requestID, speechEnd: trigger.segment.end, segmentReceived: receivedAt)
        suggestionInterval = (requestID, signposter.beginInterval("Suggestion"))
        latency.sent(requestID: requestID, at: callTime())
        await session.send(LLMRequest(id: requestID, prompt: prompt))
    }

    /// Arrête le suivi de la session et termine le flux d'affichage.
    public func stop() {
        sessionTasks.forEach { $0.cancel() }
        sessionTasks = []
        hideTask?.cancel()
        hideTask = nil
        displaysContinuation.finish()
    }

    private func handle(_ event: LLMEvent) {
        switch event {
        case .delta(let requestID, let text):
            // L'ancienne suggestion reste affichée jusqu'au premier mot montrable de la nouvelle.
            guard let shown = assembler.append(text, requestID: requestID) else { return }
            if let measurement = latency.firstWordShown(requestID: requestID, at: callTime()) {
                report(measurement)
            }
            hideTask?.cancel()
            hideTask = nil
            displaysContinuation.yield(.suggestion(shown))
        case .finished(let requestID):
            // « - » : rien à suggérer, l'ancienne suggestion garde son propre délai.
            guard assembler.finish(requestID: requestID) != nil else { return }
            scheduleHide()
        case .failed(let requestID, let message):
            logger.error("Suggestion n°\(requestID, privacy: .public) sans réponse : \(message, privacy: .private)")
        }
    }

    private func handle(_ state: SessionState) {
        switch state {
        case .restarting:
            needsFullResend = true
        case .running:
            // Le nouveau process est prêt : une demande partie pendant le redémarrage a échoué, tout est renvoyé.
            if needsFullResend {
                buffer.markAllUnsent()
                needsFullResend = false
            }
        case .stopped, .failed:
            break
        }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        let lifetime = suggestionLifetime
        hideTask = Task {
            try? await Task.sleep(for: lifetime)
            guard !Task.isCancelled else { return }
            displaysContinuation.yield(.hidden)
        }
    }

    private func report(_ measurement: LatencyMeasurement) {
        if let suggestionInterval, suggestionInterval.requestID == measurement.requestID {
            signposter.endInterval("Suggestion", suggestionInterval.state)
            self.suggestionInterval = nil
        }
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
