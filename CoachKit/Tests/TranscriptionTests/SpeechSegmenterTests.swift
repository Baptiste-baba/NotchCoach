import AudioCapture
import FluidAudio
import Testing
@testable import Transcription

/// Découpage avec un faux VAD, en blocs de 4 échantillons.
struct SpeechSegmenterTests {
    private struct FakeVADFailure: Error {}

    /// Faux VAD qui imite FluidAudio : son compteur `processedSamples` n'avance que sur un bloc traité avec succès,
    /// et il situe un début ou une fin au premier échantillon du bloc où il les repère.
    /// Un bloc de 1 est de la parole, de 0 du silence, de -1 un échec du VAD.
    private static let fakeVAD: SpeechSegmenter.Detector = { block, state in
        guard block.first != -1 else { throw FakeVADFailure() }
        var next = state
        next.processedSamples += block.count
        var event: VadStreamEvent?
        if block.first == 1, !state.triggered {
            next.triggered = true
            event = VadStreamEvent(kind: .speechStart, sampleIndex: state.processedSamples)
        } else if block.first == 0, state.triggered {
            next.triggered = false
            event = VadStreamEvent(kind: .speechEnd, sampleIndex: state.processedSamples)
        }
        return VadStreamResult(state: next, event: event, probability: 0)
    }

    private func segmenter(maximumUtteranceSampleCount: Int = 1_000) -> SpeechSegmenter {
        SpeechSegmenter(
            speaker: .prospect,
            blockSize: 4,
            accumulator: UtteranceAccumulator(maximumUtteranceSampleCount: maximumUtteranceSampleCount),
            detect: Self.fakeVAD
        )
    }

    /// Morceau dont tous les échantillons valent `value`.
    private func chunk(_ value: Float, count: Int, at start: Int) -> AudioChunk {
        AudioChunk(samples: Array(repeating: value, count: count), startTime: Double(start) / Double(AudioChunk.sampleRate))
    }

    @Test func regroupsChunksIntoBlocksAndCutsBetweenStartAndEnd() async {
        var segmenter = segmenter()
        var utterances: [Utterance] = []

        // Morceaux de 2 échantillons : regroupés en blocs de 4 avant d'atteindre le VAD.
        for (index, value) in [Float](arrayLiteral: 0, 0, 1, 1, 1, 1, 0, 0).enumerated() {
            utterances += await segmenter.append(chunk(value, count: 2, at: index * 2))
        }

        #expect(utterances.map(\.samples) == [Array(repeating: 1, count: 8)])
        #expect(utterances.first?.start == 4 / Double(AudioChunk.sampleRate))
        #expect(utterances.first?.end == 12 / Double(AudioChunk.sampleRate))
    }

    @Test func failedVadBlockDoesNotShiftLaterBoundaries() async {
        var segmenter = segmenter()
        var utterances: [Utterance] = []

        for (index, value) in [Float](arrayLiteral: 0, -1, 1, 1, 0).enumerated() {
            utterances += await segmenter.append(chunk(value, count: 4, at: index * 4))
        }

        // Exactement la parole : ni le bloc en échec, ni de parole coupée.
        #expect(utterances.map(\.samples) == [Array(repeating: 1, count: 8)])
    }

    @Test func finishTranscribesSpeechCutByTheEndOfTheAudio() async {
        var segmenter = segmenter()

        _ = await segmenter.append(chunk(1, count: 4, at: 0))
        _ = await segmenter.append(chunk(1, count: 2, at: 4))
        let utterances = segmenter.finish()

        // Le dernier morceau, plus court qu'un bloc, est compris.
        #expect(utterances.map(\.samples) == [Array(repeating: 1, count: 6)])
    }

    @Test func finishKeepsAnUtteranceCutAtTheMaximumByTheLastPartialBlock() async {
        var segmenter = segmenter(maximumUtteranceSampleCount: 10)

        _ = await segmenter.append(chunk(1, count: 8, at: 0))
        _ = await segmenter.append(chunk(1, count: 2, at: 8))
        let utterances = segmenter.finish()

        #expect(utterances.map(\.samples.count) == [10])
    }

    @Test func finishWithoutSpeechReturnsNothing() async {
        var segmenter = segmenter()

        _ = await segmenter.append(chunk(0, count: 6, at: 0))

        #expect(segmenter.finish().isEmpty)
    }
}
