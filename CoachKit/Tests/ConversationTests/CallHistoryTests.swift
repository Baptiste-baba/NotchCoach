import Testing
@testable import Conversation

private func suggestion(_ id: Int, _ text: String) -> CallDisplay.Entry {
    CallDisplay.Entry(id: id, kind: .suggestion, text: text)
}

private func failure(_ id: Int, _ text: String) -> CallDisplay.Entry {
    CallDisplay.Entry(id: id, kind: .failure, text: text)
}

struct CallHistoryTests {
    @Test func startsEmpty() {
        #expect(CallHistory().entries.isEmpty)
    }

    // MARK: Suggestions

    @Test func suggestionIsUpdatedWhileItIsWritten() {
        var history = CallHistory()

        history.showSuggestion("Je compr", requestID: 1)
        history.showSuggestion("Je comprends.", requestID: 1)

        #expect(history.entries == [suggestion(0, "Je comprends.")])
    }

    @Test func eachRequestAddsItsSuggestionBelowTheOldOnes() {
        var history = CallHistory()

        history.showSuggestion("Je comprends.", requestID: 1)
        history.showSuggestion("Deux semaines.", requestID: 2)

        #expect(history.entries == [suggestion(0, "Je comprends."), suggestion(1, "Deux semaines.")])
    }

    @Test func suggestionKeepsItsPlaceWhenAFailureComesBelowIt() {
        var history = CallHistory()
        history.showSuggestion("Je compr", requestID: 1)
        history.addFailure("Micro indisponible : aucun micro n'est disponible.")

        history.showSuggestion("Je comprends.", requestID: 1)

        #expect(history.entries == [
            suggestion(0, "Je comprends."),
            failure(1, "Micro indisponible : aucun micro n'est disponible."),
        ])
    }

    // MARK: Échecs

    @Test func failureIsAddedBelowTheSuggestions() {
        var history = CallHistory()
        history.showSuggestion("Je comprends.", requestID: 1)

        history.addFailure("Claude n'a pas pu répondre.")

        #expect(history.entries == [suggestion(0, "Je comprends."), failure(1, "Claude n'a pas pu répondre.")])
    }

    @Test func failureRepeatedInARowIsKeptOnce() {
        var history = CallHistory()

        history.addFailure("Claude n'a pas pu répondre : limite d'usage atteinte")
        history.addFailure("Claude n'a pas pu répondre : limite d'usage atteinte")

        #expect(history.entries == [failure(0, "Claude n'a pas pu répondre : limite d'usage atteinte")])
    }

    @Test func differentFailuresInARowAreAllKept() {
        var history = CallHistory()

        history.addFailure("Call sans playbook. Le playbook doit être enregistré en UTF-8.")
        history.addFailure("Claude n'a pas pu répondre.")

        #expect(history.entries.count == 2)
    }

    @Test func sameFailureAfterASuggestionIsAddedAgain() {
        var history = CallHistory()
        history.addFailure("Claude n'a pas pu répondre.")
        history.showSuggestion("Je comprends.", requestID: 1)

        history.addFailure("Claude n'a pas pu répondre.")

        // Un nouvel épisode, après une réponse réussie : il est signalé.
        #expect(history.entries == [
            failure(0, "Claude n'a pas pu répondre."),
            suggestion(1, "Je comprends."),
            failure(2, "Claude n'a pas pu répondre."),
        ])
    }
}
