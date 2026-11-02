import AudioCapture
import ClaudeSession
import Testing
import Transcription
@testable import Conversation

/// Coordinateur branché sur une fausse session Claude, et la suite de ce qu'il fait afficher.
private struct Fixture {
    let session = MockLLMSession()
    let coordinator: ConversationCoordinator
    private var displays: AsyncStream<CoachDisplay>.Iterator

    /// Par défaut, les suggestions ne se replient pas pendant le test.
    init(suggestionLifetime: Duration = .seconds(3600)) async {
        coordinator = ConversationCoordinator(session: session, callStart: .now, suggestionLifetime: suggestionLifetime)
        displays = coordinator.displays.makeAsyncIterator()
        await coordinator.start()
    }

    /// Prochain affichage décidé par le coordinateur, `nil` une fois arrêté. Attend s'il n'y en a pas encore.
    mutating func nextDisplay() async -> CoachDisplay? {
        await displays.next()
    }
}

/// Laisse le coordinateur traiter les réponses déjà émises qui n'affichent rien, avant une nouvelle demande qui les
/// rendrait obsolètes.
private func settle() async throws {
    try await Task.sleep(for: .milliseconds(50))
}

private let restartNotice = CoachDisplay.notice("Claude redémarre…")
private let unavailableError = CoachDisplay.error("Claude est indisponible. Nouvel essai à la prochaine phrase du prospect.")

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

        #expect(await fixture.nextDisplay() == .suggestion("Je compr"))
        #expect(await fixture.nextDisplay() == .suggestion("Je comprends."))
    }

    @Test func keepsTheOldSuggestionUntilTheFirstWordOfTheNewOne() async {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))
        fixture.session.emit(.finished(requestID: 1))
        #expect(await fixture.nextDisplay() == .suggestion("Je comprends."))

        await fixture.coordinator.receive(segment(.prospect, "Et le délai ?", startingAt: 10))
        fixture.session.emit(.delta(requestID: 2, text: " \n"))
        fixture.session.emit(.delta(requestID: 2, text: "Deux semaines."))

        #expect(await fixture.nextDisplay() == .suggestion("Deux semaines."))
    }

    @Test func ignoresTheAnswerToAnOlderRequest() async {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        await fixture.coordinator.receive(segment(.prospect, "Et le délai ?", startingAt: 10))

        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))
        fixture.session.emit(.failed(requestID: 1, message: "Interrompue"))
        fixture.session.emit(.delta(requestID: 2, text: "Deux semaines."))

        #expect(await fixture.nextDisplay() == .suggestion("Deux semaines."))
    }

    @Test func hidesTheSuggestionOnlyAfterTheEndOfItsAnswer() async throws {
        var fixture = await Fixture(suggestionLifetime: .milliseconds(50))
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.delta(requestID: 1, text: "Je comprends"))
        #expect(await fixture.nextDisplay() == .suggestion("Je comprends"))

        // Bien plus que la durée d'affichage : la réponse s'écrit encore, la notch ne se replie pas.
        try await Task.sleep(for: .milliseconds(200))
        fixture.session.emit(.delta(requestID: 1, text: "."))
        #expect(await fixture.nextDisplay() == .suggestion("Je comprends."))

        fixture.session.emit(.finished(requestID: 1))
        #expect(await fixture.nextDisplay() == .hidden)
    }

    @Test func newSuggestionCancelsTheHideOfThePreviousOne() async throws {
        var fixture = await Fixture(suggestionLifetime: .milliseconds(500))
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))
        fixture.session.emit(.finished(requestID: 1))
        #expect(await fixture.nextDisplay() == .suggestion("Je comprends."))
        try await settle()
        await fixture.coordinator.receive(segment(.prospect, "Et le délai ?", startingAt: 10))
        fixture.session.emit(.delta(requestID: 2, text: "Deux"))
        #expect(await fixture.nextDisplay() == .suggestion("Deux"))

        // Le repli prévu pour la première suggestion aurait eu lieu pendant cette attente.
        try await Task.sleep(for: .milliseconds(700))
        fixture.session.emit(.delta(requestID: 2, text: " semaines."))

        #expect(await fixture.nextDisplay() == .suggestion("Deux semaines."))
    }

    @Test func dashAnswerIsNeverShownAndTheOldSuggestionKeepsItsDelay() async throws {
        var fixture = await Fixture(suggestionLifetime: .milliseconds(300))
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))
        fixture.session.emit(.finished(requestID: 1))
        #expect(await fixture.nextDisplay() == .suggestion("Je comprends."))
        try await settle()

        await fixture.coordinator.receive(segment(.prospect, "Merci.", startingAt: 10))
        fixture.session.emit(.delta(requestID: 2, text: "-"))
        fixture.session.emit(.finished(requestID: 2))

        #expect(await fixture.nextDisplay() == .hidden)
    }

    // MARK: Échecs d'une réponse

    @Test func failedAnswerShowsARedMessageThatFolds() async {
        var fixture = await Fixture(suggestionLifetime: .milliseconds(50))
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))

        fixture.session.emit(.failed(requestID: 1, message: "Not logged in · Please run /login\n"))

        #expect(await fixture.nextDisplay() == .error("Claude n'a pas pu répondre : Not logged in · Please run /login"))
        #expect(await fixture.nextDisplay() == .hidden)
    }

    @Test func failedAnswerWithoutReason() async {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))

        fixture.session.emit(.failed(requestID: 1, message: ""))

        #expect(await fixture.nextDisplay() == .error("Claude n'a pas pu répondre."))
    }

    // MARK: Redémarrages de Claude

    @Test func showsANoticeWhileClaudeRestarts() async {
        var fixture = await Fixture()

        fixture.session.emit(.restarting(attempt: 1))
        fixture.session.emit(.restarting(attempt: 2))
        fixture.session.emit(.running)

        // Une seule fois le message, malgré les deux tentatives, puis la notch se replie.
        #expect(await fixture.nextDisplay() == restartNotice)
        #expect(await fixture.nextDisplay() == .hidden)
    }

    @Test func afterARestartTheWholeTranscriptIsSentAgain() async {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "Bonjour.", startingAt: 0))
        fixture.session.emit(.restarting(attempt: 1))
        fixture.session.emit(.running)
        #expect(await fixture.nextDisplay() == restartNotice)
        #expect(await fixture.nextDisplay() == .hidden)

        await fixture.coordinator.receive(segment(.me, "Bonjour Madame.", startingAt: 3))
        await fixture.coordinator.receive(segment(.prospect, "Le prix est élevé.", startingAt: 10))

        #expect(await fixture.session.requests.last == LLMRequest(
            id: 2,
            prompt: "Prospect : Bonjour.\nMoi : Bonjour Madame.\nProspect : Le prix est élevé."
        ))
    }

    @Test func noRedMessageForARequestLostDuringARestart() async throws {
        var fixture = await Fixture()
        fixture.session.emit(.restarting(attempt: 1))
        #expect(await fixture.nextDisplay() == restartNotice)
        await fixture.coordinator.receive(segment(.prospect, "Bonjour.", startingAt: 0))

        fixture.session.emit(.failed(requestID: 1, message: "Session Claude indisponible"))
        try await settle()
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 10))
        fixture.session.emit(.delta(requestID: 2, text: "Je comprends."))

        #expect(await fixture.nextDisplay() == .suggestion("Je comprends."))
    }

    @Test func claudeBackDoesNotHideAStartedSuggestion() async {
        var fixture = await Fixture()
        fixture.session.emit(.restarting(attempt: 1))
        #expect(await fixture.nextDisplay() == restartNotice)
        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 0))
        fixture.session.emit(.delta(requestID: 1, text: "Je comprends."))
        #expect(await fixture.nextDisplay() == .suggestion("Je comprends."))

        fixture.session.emit(.running)
        fixture.session.emit(.restarting(attempt: 1))

        #expect(await fixture.nextDisplay() == restartNotice)
    }

    // MARK: Claude indisponible

    @Test func nextProspectSentenceRelaunchesClaudeWithTheWholeTranscript() async {
        var fixture = await Fixture()
        await fixture.coordinator.receive(segment(.prospect, "Bonjour.", startingAt: 0))
        fixture.session.emit(.restarting(attempt: 1))
        fixture.session.emit(.failed(message: "Claude n'a pas pu redémarrer"))
        #expect(await fixture.nextDisplay() == restartNotice)
        #expect(await fixture.nextDisplay() == unavailableError)

        await fixture.coordinator.receive(segment(.prospect, "C'est trop cher.", startingAt: 10))

        #expect(await fixture.session.startCount == 1)
        #expect(await fixture.session.requests.last == LLMRequest(
            id: 2,
            prompt: "Prospect : Bonjour.\nProspect : C'est trop cher."
        ))

        // L'état `running` arrive après l'envoi : il efface le message, sans renvoyer une seconde fois la transcription.
        fixture.session.emit(.running)
        #expect(await fixture.nextDisplay() == .hidden)
        await fixture.coordinator.receive(segment(.prospect, "Et le délai ?", startingAt: 20))
        #expect(await fixture.session.requests.last == LLMRequest(id: 3, prompt: "Prospect : Et le délai ?"))
    }

    @Test func failedRelaunchSendsNothingAndTheNextSentenceTriesAgain() async {
        var fixture = await Fixture()
        fixture.session.emit(.restarting(attempt: 1))
        fixture.session.emit(.failed(message: "Claude n'a pas pu redémarrer"))
        #expect(await fixture.nextDisplay() == restartNotice)
        #expect(await fixture.nextDisplay() == unavailableError)

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

    // MARK: Arrêt

    @Test func stopEndsTheDisplays() async {
        var fixture = await Fixture()

        await fixture.coordinator.stop()

        #expect(await fixture.nextDisplay() == nil)
    }
}
