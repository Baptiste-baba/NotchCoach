import AudioCapture
import ClaudeSession
import Testing
import Transcription
@testable import Conversation

/// Une entrée attendue dans l'historique, sans son identifiant : sa place.
private enum Expected {
    case suggestion(String)
    case failure(String)
}

/// Affichage attendu : l'historique, du plus ancien au plus récent, et le message passager.
private func display(_ entries: Expected..., notice: String? = nil) -> CallDisplay {
    CallDisplay(
        entries: entries.enumerated().map { index, entry in
            switch entry {
            case .suggestion(let text): CallDisplay.Entry(id: index, kind: .suggestion, text: text)
            case .failure(let text): CallDisplay.Entry(id: index, kind: .failure, text: text)
            }
        },
        notice: notice
    )
}

/// Coordinateur branché sur une fausse session Claude, et la suite de ce qu'il fait afficher.
private struct Fixture {
    let session = MockLLMSession()
    let coordinator: ConversationCoordinator
    private var displays: AsyncStream<CallDisplay>.Iterator

    init() async {
        coordinator = ConversationCoordinator(session: session, callStart: .now)
        displays = coordinator.displays.makeAsyncIterator()
        await coordinator.start()
    }

    /// Prochain affichage publié par le coordinateur, `nil` une fois arrêté. Attend s'il n'y en a pas encore.
    mutating func nextDisplay() async -> CallDisplay? {
        await displays.next()
    }
}

/// Laisse le coordinateur traiter les réponses déjà émises qui n'affichent rien, avant une nouvelle demande qui les
/// rendrait obsolètes.
private func settle() async throws {
    try await Task.sleep(for: .milliseconds(50))
}

private let restartNotice = "Claude redémarre…"
private let unavailable = "Claude est indisponible. Nouvel essai à la prochaine phrase du prospect."

@Suite(.timeLimit(.minutes(1)))
struct ConversationCoordinatorTests {
    // MARK: Demandes

    @Test func prospectSentenceSendsTheNewLines() async {
        let fixture = await Fixture()

        await fixture.coordinator.receive(segment(.me, "Qu'en pensez-vous ?", startingAt: 0))
        #expect(await fixture.session.requests.isEmpty)
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 3))
        await fixture.coordinator.receive(segment(.me, "Je comprends.", startingAt: 6))
        await fixture.coordinator.receive(segment(.prospect, "Et le délai ?", startingAt: 10))

        #expect(await fixture.session.requests == [
            LLMRequest(id: 1, prompt: "Moi : Qu'en pensez-vous ?\nProspect : C'est trop cher."),
            LLMRequest(id: 2, prompt: "Moi : Je comprends.\nProspect : Et le délai ?"),
        ])
    }

    // MARK: Suggestions

    @Test func showsTheSuggestionAsItIsWritten() async {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))

        fixture.session.emit(.delta(requestID: 1, text: "Je compr"))
        fixture.session.emit(.delta(requestID: 1, text: "ends."))

        #expect(await fixture.nextDisplay() == display(.suggestion("Je compr")))
        #expect(await fixture.nextDisplay() == display(.suggestion("Je comprends.")))
    }

    @Test func newSuggestionComesBelowTheOldOneAtItsFirstWord() async {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))
        fixture.session.emit(.finished(requestID: 1))
        #expect(await fixture.nextDisplay() == display(.suggestion("Je comprends.")))

        await fixture.coordinator.receive(segment(.prospect, "Et le délai ?", startingAt: 10))
        fixture.session.emit(.delta(requestID: 2, text: " \n"))
        fixture.session.emit(.delta(requestID: 2, text: "Deux semaines."))

        // Rien n'est publié pour le texte encore blanc : l'ancienne suggestion reste la dernière entrée jusque-là.
        #expect(await fixture.nextDisplay() == display(.suggestion("Je comprends."), .suggestion("Deux semaines.")))
    }

    @Test func ignoresTheAnswerToAnOlderRequest() async {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        await fixture.coordinator.receive(segment(.prospect, "Et le délai ?", startingAt: 10))

        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))
        fixture.session.emit(.failed(requestID: 1, message: "Interrompue"))
        fixture.session.emit(.delta(requestID: 2, text: "Deux semaines."))

        #expect(await fixture.nextDisplay() == display(.suggestion("Deux semaines.")))
    }

    @Test func suggestionStaysUntilTheEndOfTheCall() async throws {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))
        fixture.session.emit(.finished(requestID: 1))
        #expect(await fixture.nextDisplay() == display(.suggestion("Je comprends.")))

        try await Task.sleep(for: .milliseconds(200))
        await fixture.coordinator.stop()

        // Aucun repli n'a été publié avant la fin du call.
        #expect(await fixture.nextDisplay() == nil)
    }

    @Test func dashAnswerChangesNothing() async throws {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))
        fixture.session.emit(.finished(requestID: 1))
        #expect(await fixture.nextDisplay() == display(.suggestion("Je comprends.")))

        await fixture.coordinator.receive(segment(.prospect, "Merci.", startingAt: 10))
        fixture.session.emit(.delta(requestID: 2, text: "-"))
        fixture.session.emit(.finished(requestID: 2))
        try await settle()
        await fixture.coordinator.stop()

        #expect(await fixture.nextDisplay() == nil)
    }

    // MARK: Échecs d'une réponse

    @Test func failedAnswerJoinsTheHistoryInRed() async {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))
        fixture.session.emit(.finished(requestID: 1))
        #expect(await fixture.nextDisplay() == display(.suggestion("Je comprends.")))

        await fixture.coordinator.receive(segment(.prospect, "Et le délai ?", startingAt: 10))
        fixture.session.emit(.failed(requestID: 2, message: "Not logged in · Please run /login\n"))

        #expect(await fixture.nextDisplay() == display(
            .suggestion("Je comprends."),
            .failure("Claude n'a pas pu répondre : Not logged in · Please run /login")
        ))
    }

    @Test func sameFailureAgainPublishesNothing() async throws {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.failed(requestID: 1, message: "Overloaded"))
        #expect(await fixture.nextDisplay() == display(.failure("Claude n'a pas pu répondre : Overloaded")))

        await fixture.coordinator.receive(segment(.prospect, "Et le délai ?", startingAt: 10))
        fixture.session.emit(.failed(requestID: 2, message: "Overloaded"))
        try await settle()
        await fixture.coordinator.stop()

        // L'historique n'a pas changé : rien n'est republié avant la fin du call.
        #expect(await fixture.nextDisplay() == nil)
    }

    @Test func failedAnswerWithoutReason() async {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))

        fixture.session.emit(.failed(requestID: 1, message: ""))

        #expect(await fixture.nextDisplay() == display(.failure("Claude n'a pas pu répondre.")))
    }

    // MARK: Erreurs de l'appelant

    @Test func callerErrorJoinsTheHistoryInRed() async {
        var fixture = await Fixture()

        await fixture.coordinator.showError("Call sans playbook.")

        #expect(await fixture.nextDisplay() == display(.failure("Call sans playbook.")))
    }

    @Test func nextSuggestionComesBelowTheCallerError() async {
        var fixture = await Fixture()
        await fixture.coordinator.showError("Call sans playbook.")
        #expect(await fixture.nextDisplay() == display(.failure("Call sans playbook.")))

        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))

        #expect(await fixture.nextDisplay() == display(.failure("Call sans playbook."), .suggestion("Je comprends.")))
    }

    // MARK: Redémarrages de Claude

    @Test func showsANoticeWhileClaudeRestarts() async {
        var fixture = await Fixture()

        fixture.session.emit(.restarting(attempt: 1))
        fixture.session.emit(.restarting(attempt: 2))
        fixture.session.emit(.running)

        // Une seule fois le message, malgré les deux tentatives, puis il disparaît.
        #expect(await fixture.nextDisplay() == display(notice: restartNotice))
        #expect(await fixture.nextDisplay() == display())
    }

    @Test func afterARestartTheWholeTranscriptIsSentAgain() async {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "Bonjour.", startingAt: 0))
        fixture.session.emit(.restarting(attempt: 1))
        fixture.session.emit(.running)
        #expect(await fixture.nextDisplay() == display(notice: restartNotice))
        #expect(await fixture.nextDisplay() == display())

        await fixture.coordinator.receive(segment(.me, "Bonjour Madame.", startingAt: 3))
        await fixture.coordinator.receive(segment(.prospect, "Le prix est élevé.", startingAt: 10))

        #expect(await fixture.session.requests.last == LLMRequest(
            id: 2,
            prompt: "Prospect : Bonjour.\nMoi : Bonjour Madame.\nProspect : Le prix est élevé."
        ))
    }

    @Test func noRedEntryForARequestLostDuringARestart() async throws {
        var fixture = await Fixture()
        fixture.session.emit(.restarting(attempt: 1))
        #expect(await fixture.nextDisplay() == display(notice: restartNotice))
        await fixture.coordinator.receive(segment(.prospect, "Bonjour.", startingAt: 0))

        fixture.session.emit(.failed(requestID: 1, message: "Session Claude indisponible"))
        try await settle()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 10))
        fixture.session.emit(.delta(requestID: 2, text: "Je comprends."))

        #expect(await fixture.nextDisplay() == display(.suggestion("Je comprends."), notice: restartNotice))
    }

    @Test func claudeBackKeepsTheHistory() async {
        var fixture = await Fixture()
        fixture.session.emit(.restarting(attempt: 1))
        #expect(await fixture.nextDisplay() == display(notice: restartNotice))
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))
        #expect(await fixture.nextDisplay() == display(.suggestion("Je comprends."), notice: restartNotice))

        fixture.session.emit(.running)

        #expect(await fixture.nextDisplay() == display(.suggestion("Je comprends.")))
    }

    // MARK: Claude indisponible

    @Test func nextProspectSentenceRelaunchesClaudeWithTheWholeTranscript() async throws {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "Bonjour.", startingAt: 0))
        fixture.session.emit(.restarting(attempt: 1))
        fixture.session.emit(.failed(message: "Claude n'a pas pu redémarrer"))
        #expect(await fixture.nextDisplay() == display(notice: restartNotice))
        #expect(await fixture.nextDisplay() == display(.failure(unavailable)))

        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 10))

        #expect(await fixture.session.startCount == 1)
        #expect(await fixture.session.requests.last == LLMRequest(
            id: 2,
            prompt: "Prospect : Bonjour.\nProspect : C'est trop cher."
        ))

        // L'état `running` arrive après l'envoi : la transcription n'est pas renvoyée une seconde fois.
        fixture.session.emit(.running)
        try await settle()
        await fixture.coordinator.receive(segment(.prospect, "Et le délai ?", startingAt: 20))
        #expect(await fixture.session.requests.last == LLMRequest(id: 3, prompt: "Prospect : Et le délai ?"))
    }

    @Test func failedRelaunchSendsNothingAndTheNextSentenceTriesAgain() async {
        var fixture = await Fixture()
        fixture.session.emit(.restarting(attempt: 1))
        fixture.session.emit(.failed(message: "Claude n'a pas pu redémarrer"))
        #expect(await fixture.nextDisplay() == display(notice: restartNotice))
        #expect(await fixture.nextDisplay() == display(.failure(unavailable)))

        await fixture.session.setStartFails(true)
        await fixture.coordinator.receive(segment(.prospect, "Bonjour.", startingAt: 0))
        #expect(await fixture.session.requests.isEmpty)

        await fixture.session.setStartFails(false)
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 10))

        #expect(await fixture.session.startCount == 2)
        #expect(await fixture.session.requests == [
            LLMRequest(id: 2, prompt: "Prospect : Bonjour.\nProspect : C'est trop cher."),
        ])
    }

    // MARK: Fin du call

    @Test func stopEndsTheDisplays() async {
        var fixture = await Fixture()

        await fixture.coordinator.stop()

        #expect(await fixture.nextDisplay() == nil)
    }

    @Test func noRequestAfterTheStop() async {
        let fixture = await Fixture()
        fixture.session.emit(.failed(message: "Claude n'a pas pu redémarrer"))
        await fixture.coordinator.stop()

        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))

        // Ni demande, ni relance de Claude une fois le call fini.
        #expect(await fixture.session.requests.isEmpty)
        #expect(await fixture.session.startCount == 0)
    }
}
