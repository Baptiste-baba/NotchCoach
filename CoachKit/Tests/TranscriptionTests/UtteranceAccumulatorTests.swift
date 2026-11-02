import AudioCapture
import Testing
@testable import Transcription

/// Les échantillons valent leur index depuis le début du flux : on lit directement quel extrait est retenu.
struct UtteranceAccumulatorTests {
    private let rate = Double(AudioChunk.sampleRate)

    /// Morceau de `count` échantillons commençant à l'index `start` du flux.
    private func chunk(from start: Int, count: Int, streamStart: Double = 0) -> AudioChunk {
        AudioChunk(samples: (start..<start + count).map(Float.init), startTime: streamStart + Double(start) / rate)
    }

    @Test func emitsTheSamplesBetweenStartAndEnd() {
        var accumulator = UtteranceAccumulator()

        #expect(accumulator.append(chunk(from: 0, count: 100), boundary: .start(sampleIndex: 20)) == nil)
        let utterance = accumulator.append(chunk(from: 100, count: 100), boundary: .end(sampleIndex: 150))

        #expect(utterance?.samples == (20..<150).map(Float.init))
        #expect(utterance?.start == 20 / rate)
        #expect(utterance?.end == 150 / rate)
    }

    @Test func keepsTheAudioJustBeforeAStartDetectedLate() {
        var accumulator = UtteranceAccumulator(lookbackSampleCount: 100)

        _ = accumulator.append(chunk(from: 0, count: 100), boundary: nil)
        _ = accumulator.append(chunk(from: 100, count: 100), boundary: .start(sampleIndex: 120))
        let utterance = accumulator.append(chunk(from: 200, count: 100), boundary: .end(sampleIndex: 250))

        #expect(utterance?.samples.first == 120)
        #expect(utterance?.samples.count == 130)
    }

    @Test func startOlderThanTheKeptAudioBeginsAtTheOldestKeptSample() {
        var accumulator = UtteranceAccumulator(lookbackSampleCount: 50)

        _ = accumulator.append(chunk(from: 0, count: 100), boundary: nil)
        _ = accumulator.append(chunk(from: 100, count: 100), boundary: .start(sampleIndex: 10))
        let utterance = accumulator.append(chunk(from: 200, count: 10), boundary: .end(sampleIndex: 205))

        // Après le premier morceau, seuls les 50 derniers échantillons (50 à 99) étaient gardés.
        #expect(utterance?.samples.first == 50)
        #expect(utterance?.start == 50 / rate)
    }

    @Test func endWithoutStartIsIgnored() {
        var accumulator = UtteranceAccumulator()

        #expect(accumulator.append(chunk(from: 0, count: 100), boundary: .end(sampleIndex: 50)) == nil)
        #expect(accumulator.finish() == nil)
    }

    @Test func secondStartKeepsTheUtteranceGoing() {
        var accumulator = UtteranceAccumulator()

        _ = accumulator.append(chunk(from: 0, count: 100), boundary: .start(sampleIndex: 10))
        _ = accumulator.append(chunk(from: 100, count: 100), boundary: .start(sampleIndex: 150))
        let utterance = accumulator.append(chunk(from: 200, count: 100), boundary: .end(sampleIndex: 250))

        #expect(utterance?.samples.first == 10)
        #expect(utterance?.samples.last == 249)
    }

    @Test func endBeyondTheReceivedAudioStopsAtItsLastSample() {
        var accumulator = UtteranceAccumulator()

        _ = accumulator.append(chunk(from: 0, count: 100), boundary: .start(sampleIndex: 10))
        let utterance = accumulator.append(chunk(from: 100, count: 100), boundary: .end(sampleIndex: 900))

        #expect(utterance?.samples.last == 199)
        #expect(utterance?.end == 200 / rate)
    }

    @Test func endBeforeItsStartGivesNoUtterance() {
        var accumulator = UtteranceAccumulator()

        _ = accumulator.append(chunk(from: 0, count: 100), boundary: .start(sampleIndex: 80))
        #expect(accumulator.append(chunk(from: 100, count: 100), boundary: .end(sampleIndex: 40)) == nil)
        #expect(accumulator.finish() == nil)
    }

    @Test func longUtteranceIsCutAtTheMaximumAndContinues() {
        var accumulator = UtteranceAccumulator(maximumUtteranceSampleCount: 150)

        _ = accumulator.append(chunk(from: 0, count: 100), boundary: .start(sampleIndex: 0))
        let first = accumulator.append(chunk(from: 100, count: 100), boundary: nil)
        let second = accumulator.append(chunk(from: 200, count: 100), boundary: .end(sampleIndex: 260))

        #expect(first?.samples == (0..<200).map(Float.init))
        #expect(second?.samples == (200..<260).map(Float.init))
    }

    @Test func finishReturnsTheUtteranceCutByTheEndOfTheAudio() {
        var accumulator = UtteranceAccumulator()

        _ = accumulator.append(chunk(from: 0, count: 100), boundary: .start(sampleIndex: 30))
        _ = accumulator.append(chunk(from: 100, count: 50), boundary: nil)
        let utterance = accumulator.finish()

        #expect(utterance?.samples == (30..<150).map(Float.init))
        #expect(accumulator.finish() == nil)
    }

    @Test func finishWithoutSpeechReturnsNothing() {
        var accumulator = UtteranceAccumulator()

        _ = accumulator.append(chunk(from: 0, count: 100), boundary: nil)

        #expect(accumulator.finish() == nil)
    }

    @Test func timesCountFromTheFirstChunkOfTheCall() {
        var accumulator = UtteranceAccumulator()

        _ = accumulator.append(chunk(from: 0, count: 100, streamStart: 12), boundary: .start(sampleIndex: 16))
        let utterance = accumulator.append(chunk(from: 100, count: 100, streamStart: 12), boundary: .end(sampleIndex: 160))

        #expect(utterance?.start == 12 + 16 / rate)
        #expect(utterance?.end == 12 + 160 / rate)
    }
}
