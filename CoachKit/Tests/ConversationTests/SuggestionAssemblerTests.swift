import Testing
@testable import Conversation

struct SuggestionAssemblerTests {
    @Test func showsTheTextAsItArrives() {
        var assembler = SuggestionAssembler()
        assembler.start(requestID: 1)

        #expect(assembler.append("Je compr", requestID: 1) == "Je compr")
        #expect(assembler.append("ends.", requestID: 1) == "Je comprends.")
    }

    @Test func trimsSurroundingWhitespace() {
        var assembler = SuggestionAssembler()
        assembler.start(requestID: 1)

        #expect(assembler.append("\n Oui. ", requestID: 1) == "Oui.")
    }

    @Test func showsNothingWhileTheTextIsBlank() {
        var assembler = SuggestionAssembler()
        assembler.start(requestID: 1)

        #expect(assembler.append(" \n", requestID: 1) == nil)
        #expect(assembler.finish(requestID: 1) == nil)
    }

    @Test func neverShowsTheDashAnswer() {
        var assembler = SuggestionAssembler()
        assembler.start(requestID: 1)

        #expect(assembler.append("-", requestID: 1) == nil)
        #expect(assembler.append("\n", requestID: 1) == nil)
        #expect(assembler.finish(requestID: 1) == nil)
    }

    @Test func dashFollowedByTextIsShown() {
        var assembler = SuggestionAssembler()
        assembler.start(requestID: 1)

        #expect(assembler.append("-", requestID: 1) == nil)
        #expect(assembler.append("20 % si vous signez ce mois-ci.", requestID: 1) == "-20 % si vous signez ce mois-ci.")
    }

    @Test func finishReturnsTheFinalText() {
        var assembler = SuggestionAssembler()
        assembler.start(requestID: 1)
        _ = assembler.append("Oui, bien sûr.", requestID: 1)

        #expect(assembler.finish(requestID: 1) == "Oui, bien sûr.")
    }

    @Test func newRequestStartsFromScratchAndIgnoresTheOldOne() {
        var assembler = SuggestionAssembler()
        assembler.start(requestID: 1)
        _ = assembler.append("Ancienne", requestID: 1)
        assembler.start(requestID: 2)

        #expect(assembler.append(" réponse", requestID: 1) == nil)
        #expect(assembler.append("Nouvelle", requestID: 2) == "Nouvelle")
        #expect(assembler.finish(requestID: 1) == nil)
        let failedOldRequest = assembler.fail(requestID: 1)
        #expect(!failedOldRequest)
    }

    @Test func ignoresTextAfterTheEndOfTheAnswer() {
        var assembler = SuggestionAssembler()
        assembler.start(requestID: 1)
        _ = assembler.append("Oui.", requestID: 1)
        _ = assembler.finish(requestID: 1)

        #expect(assembler.append(" Encore.", requestID: 1) == nil)
        #expect(assembler.finish(requestID: 1) == nil)
    }

    @Test func isAnsweringFromTheRequestToTheEndOfItsAnswer() {
        var assembler = SuggestionAssembler()
        #expect(!assembler.isAnswering)

        assembler.start(requestID: 1)
        #expect(assembler.isAnswering)
        _ = assembler.append("Oui.", requestID: 1)
        #expect(assembler.isAnswering)
        _ = assembler.finish(requestID: 1)
        #expect(!assembler.isAnswering)

        assembler.start(requestID: 2)
        _ = assembler.fail(requestID: 2)
        #expect(!assembler.isAnswering)
    }

    @Test func failureEndsTheCurrentAnswer() {
        var assembler = SuggestionAssembler()
        assembler.start(requestID: 1)

        let failed = assembler.fail(requestID: 1)
        #expect(failed)
        #expect(assembler.append("Oui.", requestID: 1) == nil)
        let failedAgain = assembler.fail(requestID: 1)
        #expect(!failedAgain)
    }
}
