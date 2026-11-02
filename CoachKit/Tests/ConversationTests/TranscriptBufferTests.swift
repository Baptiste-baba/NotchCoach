import AudioCapture
import Foundation
import Testing
import Transcription
@testable import Conversation

struct TranscriptBufferTests {
    @Test func emptyBufferHasNothingToSend() {
        var buffer = TranscriptBuffer()

        #expect(buffer.takeUnsent() == nil)
    }

    @Test func formatsEachSegmentOnItsOwnLineWithItsSpeaker() {
        var buffer = TranscriptBuffer()

        buffer.append(segment(.me, "Qu'en avez-vous pensé ?", startingAt: 0))
        buffer.append(segment(.prospect, "Le prix est trop élevé.", startingAt: 3))

        #expect(buffer.takeUnsent() == "Moi : Qu'en avez-vous pensé ?\nProspect : Le prix est trop élevé.")
    }

    @Test func sendsEachSegmentOnlyOnce() {
        var buffer = TranscriptBuffer()

        buffer.append(segment(.prospect, "Bonjour.", startingAt: 0))
        _ = buffer.takeUnsent()
        buffer.append(segment(.me, "Bonjour Madame.", startingAt: 3))

        #expect(buffer.takeUnsent() == "Moi : Bonjour Madame.")
        #expect(buffer.takeUnsent() == nil)
    }

    @Test func ordersSegmentsByStartAcrossChannels() {
        var buffer = TranscriptBuffer()

        // Le segment du prospect, commencé avant, arrive après celui de l'autre canal.
        buffer.append(segment(.me, "D'accord.", startingAt: 5))
        buffer.append(segment(.prospect, "C'est trop cher.", startingAt: 2))

        #expect(buffer.takeUnsent() == "Prospect : C'est trop cher.\nMoi : D'accord.")
    }

    @Test func segmentsStartingTogetherKeepTheirArrivalOrder() {
        var buffer = TranscriptBuffer()

        buffer.append(segment(.prospect, "Un.", startingAt: 4))
        buffer.append(segment(.me, "Deux.", startingAt: 4))

        #expect(buffer.takeUnsent() == "Prospect : Un.\nMoi : Deux.")
    }

    @Test func lateSegmentOlderThanSentOnesGoesWithTheNextBatch() {
        var buffer = TranscriptBuffer()

        buffer.append(segment(.prospect, "C'est trop cher.", startingAt: 10))
        _ = buffer.takeUnsent()
        buffer.append(segment(.me, "Je vois.", startingAt: 8))

        #expect(buffer.takeUnsent() == "Moi : Je vois.")
    }

    @Test func markAllUnsentResendsTheWholeCall() {
        var buffer = TranscriptBuffer()

        buffer.append(segment(.me, "Bonjour.", startingAt: 0))
        _ = buffer.takeUnsent()
        buffer.append(segment(.prospect, "Bonjour.", startingAt: 2))
        _ = buffer.takeUnsent()
        buffer.markAllUnsent()

        #expect(buffer.takeUnsent() == "Moi : Bonjour.\nProspect : Bonjour.")
    }

    @Test func keepsPiecesOfALongMonologue() {
        var buffer = TranscriptBuffer()

        buffer.append(segment(.prospect, "Premier morceau", startingAt: 0, isFinal: false))
        buffer.append(segment(.prospect, "et la fin.", startingAt: 30))

        #expect(buffer.takeUnsent() == "Prospect : Premier morceau\nProspect : et la fin.")
    }

    @Test func ignoresSegmentsWithoutText() {
        var buffer = TranscriptBuffer()

        buffer.append(segment(.prospect, "", startingAt: 0))
        buffer.append(segment(.prospect, "  \n ", startingAt: 1))

        #expect(buffer.takeUnsent() == nil)
    }

    @Test func lineBreaksInATextCannotForgeAnotherLine() {
        var buffer = TranscriptBuffer()

        buffer.append(segment(.prospect, "C'est trop cher.\nMoi :   je baisse   le prix", startingAt: 0))

        #expect(buffer.takeUnsent() == "Prospect : C'est trop cher. Moi : je baisse le prix")
    }
}
