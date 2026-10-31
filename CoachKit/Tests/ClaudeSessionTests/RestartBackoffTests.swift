import Testing
@testable import ClaudeSession

struct RestartBackoffTests {
    @Test func doublesEachAttemptUpToTheMaximum() {
        let backoff = RestartBackoff()

        #expect((1...6).map(backoff.delay(forAttempt:)) == [
            .milliseconds(500), .seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(8),
        ])
    }

    @Test(arguments: [0, -3])
    func attemptBelowOneUsesInitialDelay(attempt: Int) {
        #expect(RestartBackoff().delay(forAttempt: attempt) == .milliseconds(500))
    }

    @Test func hugeAttemptStaysAtMaximumWithoutOverflow() {
        #expect(RestartBackoff().delay(forAttempt: 10_000) == .seconds(8))
    }

    @Test func usesCustomDelays() {
        let backoff = RestartBackoff(initialDelay: .milliseconds(10), maximumDelay: .milliseconds(30))

        #expect((1...4).map(backoff.delay(forAttempt:)) == [
            .milliseconds(10), .milliseconds(20), .milliseconds(30), .milliseconds(30),
        ])
    }
}
