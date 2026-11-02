import Testing
@testable import Conversation

struct LatencyTrackerTests {
    @Test func measuresEachStepUpToTheFirstWord() {
        var tracker = LatencyTracker()
        tracker.triggered(requestID: 1, speechEnd: 10, segmentReceived: 11)
        tracker.sent(requestID: 1, at: 11.5)

        let measurement = tracker.firstWordShown(requestID: 1, at: 13)

        #expect(measurement == LatencyMeasurement(
            requestID: 1,
            speechEnd: 10,
            segmentReceived: 11,
            requestSent: 11.5,
            firstWordShown: 13
        ))
        #expect(measurement?.endOfTurnDetection == 1)
        #expect(measurement?.dispatch == 0.5)
        #expect(measurement?.firstWord == 1.5)
        #expect(measurement?.total == 3)
    }

    @Test func reportsEachRequestOnlyOnce() {
        var tracker = LatencyTracker()
        tracker.triggered(requestID: 1, speechEnd: 10, segmentReceived: 11)
        tracker.sent(requestID: 1, at: 11.5)
        _ = tracker.firstWordShown(requestID: 1, at: 13)

        #expect(tracker.firstWordShown(requestID: 1, at: 14) == nil)
    }

    @Test func newRequestReplacesTheMeasurementOfTheOldOne() {
        var tracker = LatencyTracker()
        tracker.triggered(requestID: 1, speechEnd: 10, segmentReceived: 11)
        tracker.sent(requestID: 1, at: 11.5)
        tracker.triggered(requestID: 2, speechEnd: 20, segmentReceived: 21)
        tracker.sent(requestID: 2, at: 21.5)

        #expect(tracker.firstWordShown(requestID: 1, at: 22) == nil)
        #expect(tracker.firstWordShown(requestID: 2, at: 23)?.total == 3)
    }

    @Test func noMeasurementBeforeTheRequestIsSent() {
        var tracker = LatencyTracker()
        tracker.triggered(requestID: 1, speechEnd: 10, segmentReceived: 11)
        tracker.sent(requestID: 2, at: 11.5)

        #expect(tracker.firstWordShown(requestID: 1, at: 13) == nil)
    }
}
