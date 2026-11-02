import AudioCapture
import Foundation
import Testing
import Transcription
@testable import Conversation

struct TriggerDetectorTests {
    /// Segment qui finit à `end` secondes du début du call.
    private func segment(
        _ speaker: Speaker,
        endingAt end: TimeInterval,
        text: String = "Le prix est trop élevé.",
        isFinal: Bool = true
    ) -> TranscriptSegment {
        TranscriptSegment(speaker: speaker, text: text, isFinal: isFinal, start: end - 2, end: end)
    }

    @Test func finalProspectSegmentTriggersRightAway() {
        var detector = TriggerDetector()
        let prospect = segment(.prospect, endingAt: 10)

        #expect(detector.receive(prospect) == Trigger(requestID: 1, segment: prospect))
    }

    @Test func mySegmentsNeverTrigger() {
        var detector = TriggerDetector()

        #expect(detector.receive(segment(.me, endingAt: 10)) == nil)
    }

    @Test func pieceOfALongMonologueDoesNotTrigger() {
        var detector = TriggerDetector()

        #expect(detector.receive(segment(.prospect, endingAt: 30, isFinal: false)) == nil)
        #expect(detector.receive(segment(.prospect, endingAt: 34))?.requestID == 1)
    }

    @Test func emptyFinalSegmentClosingAMonologueTriggers() {
        var detector = TriggerDetector()

        _ = detector.receive(segment(.prospect, endingAt: 30, isFinal: false))

        #expect(detector.receive(segment(.prospect, endingAt: 30.4, text: ""))?.requestID == 1)
    }

    @Test func noNewTriggerWithinTheCooldown() {
        var detector = TriggerDetector()

        _ = detector.receive(segment(.prospect, endingAt: 10))

        #expect(detector.receive(segment(.prospect, endingAt: 14.9)) == nil)
        #expect(detector.receive(segment(.prospect, endingAt: 15))?.requestID == 2)
    }

    @Test func requestIDsGrowOnlyWithTriggers() {
        var detector = TriggerDetector()

        let ids = [
            detector.receive(segment(.prospect, endingAt: 10)),
            detector.receive(segment(.me, endingAt: 12)),
            detector.receive(segment(.prospect, endingAt: 13)),
            detector.receive(segment(.prospect, endingAt: 20)),
            detector.receive(segment(.prospect, endingAt: 30)),
        ].compactMap { $0?.requestID }

        #expect(ids == [1, 2, 3])
    }

    @Test func lateOlderSegmentDoesNotTrigger() {
        var detector = TriggerDetector()

        _ = detector.receive(segment(.prospect, endingAt: 20))

        #expect(detector.receive(segment(.prospect, endingAt: 8)) == nil)
    }

    @Test func zeroCooldownTriggersOnEveryFinalProspectSegment() {
        var detector = TriggerDetector(cooldown: 0)

        _ = detector.receive(segment(.prospect, endingAt: 10))

        #expect(detector.receive(segment(.prospect, endingAt: 10.5))?.requestID == 2)
    }
}
