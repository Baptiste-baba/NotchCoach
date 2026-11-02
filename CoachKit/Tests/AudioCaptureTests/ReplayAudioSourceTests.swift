import Foundation
import Testing
@testable import AudioCapture

/// Lecture réelle de petits fichiers de synthèse, à vitesse réelle : chaque test dure au plus une seconde.
struct ReplayAudioSourceTests {
    private let files: TemporaryAudioFiles

    init() throws {
        files = try TemporaryAudioFiles()
    }

    private static func collect(_ stream: AsyncStream<AudioChunk>) async -> [AudioChunk] {
        var chunks: [AudioChunk] = []
        for await chunk in stream {
            chunks.append(chunk)
        }
        return chunks
    }

    /// Joue le fichier jusqu'au bout et renvoie les morceaux de chaque canal.
    private func play(_ url: URL) async throws -> (me: [AudioChunk], prospect: [AudioChunk]) {
        let source = ReplayAudioSource(file: url)
        async let me = Self.collect(source.chunks(of: .me))
        async let prospect = Self.collect(source.chunks(of: .prospect))
        try await source.start()
        return await (me, prospect)
    }

    @Test func leftChannelIsMeAndRightChannelIsTheProspect() async throws {
        let url = try files.wav(frameCount: 9_600, channelValues: [0.25, -0.5])

        let (me, prospect) = try await play(url)

        let meSamples = me.flatMap(\.samples)
        let prospectSamples = prospect.flatMap(\.samples)
        #expect(meSamples.count == 9_600)
        #expect(prospectSamples.count == 9_600)
        #expect(Set(meSamples) == [0.25])
        #expect(Set(prospectSamples) == [-0.5])
    }

    @Test func emitsVadSizedBlocksTimedFromTheStartOfTheCall() async throws {
        let url = try files.wav(frameCount: 9_600, channelValues: [0.1, 0.2])

        let (me, prospect) = try await play(url)

        #expect(me.map(\.samples.count) == [4_096, 4_096, 1_408])
        #expect(me.map(\.startTime) == [0, 0.256, 0.512])
        #expect(prospect.map(\.startTime) == me.map(\.startTime))
    }

    @Test func playsAtRealTimeSpeed() async throws {
        let url = try files.wav(frameCount: 9_600, channelValues: [0.1, 0.2])
        let clock = ContinuousClock()

        let elapsed = try await clock.measure { _ = try await play(url) }

        // 9600 échantillons à 16 kHz = 0,6 s : chaque bloc est émis à sa fin.
        #expect(elapsed >= .milliseconds(580))
        #expect(elapsed < .seconds(2))
    }

    @Test func resamplesTo16kHz() async throws {
        let url = try files.wav(sampleRate: 48_000, frameCount: 14_400, channelValues: [0.25, -0.5])

        let (me, _) = try await play(url)

        // 0,3 s à 48 kHz donne environ 4800 échantillons à 16 kHz, au délai du convertisseur près.
        let samples = me.flatMap(\.samples)
        #expect(abs(samples.count - 4_800) <= 200)
        #expect(abs(samples[samples.count / 2] - 0.25) < 0.01)
    }

    @Test func missingFileFailsToStart() async throws {
        let url = files.directory.appendingPathComponent("inexistant.wav")
        let source = ReplayAudioSource(file: url)

        await #expect(throws: AudioCaptureError.replayFileNotFound(path: url.path)) {
            try await source.start()
        }
    }

    @Test func monoFileFailsToStart() async throws {
        let source = ReplayAudioSource(file: try files.wav(frameCount: 1_600, channelValues: [0.1]))

        await #expect(throws: AudioCaptureError.replayFileNotStereo(channelCount: 1)) {
            try await source.start()
        }
    }

    @Test func fileThatIsNotAudioFailsToStart() async throws {
        let source = ReplayAudioSource(file: try files.notAudio())

        let error = await #expect(throws: AudioCaptureError.self) {
            try await source.start()
        }
        guard case .replayFileUnreadable = error else {
            Issue.record("erreur inattendue : \(String(describing: error))")
            return
        }
    }

    @Test func stopEndsBothStreamsBeforeTheEndOfTheFile() async throws {
        // 5 s de fichier.
        let source = ReplayAudioSource(file: try files.wav(frameCount: 80_000, channelValues: [0.1, 0.2]))
        let clock = ContinuousClock()

        let elapsed = try await clock.measure {
            async let me = Self.collect(source.chunks(of: .me))
            async let prospect = Self.collect(source.chunks(of: .prospect))
            try await source.start()
            try await Task.sleep(for: .milliseconds(300))
            await source.stop()
            let (meChunks, prospectChunks) = await (me, prospect)
            #expect(meChunks.count < 20)
            #expect(prospectChunks.count < 20)
        }

        #expect(elapsed < .seconds(2))
    }

    @Test func startAfterStopDoesNothing() async throws {
        let source = ReplayAudioSource(file: try files.wav(frameCount: 9_600, channelValues: [0.1, 0.2]))

        await source.stop()
        try await source.start()

        #expect(await Self.collect(source.chunks(of: .me)).isEmpty)
    }

    @Test func secondStartDoesNotPlayTheFileTwice() async throws {
        let source = ReplayAudioSource(file: try files.wav(frameCount: 9_600, channelValues: [0.1, 0.2]))

        async let me = Self.collect(source.chunks(of: .me))
        try await source.start()
        try await source.start()

        #expect(await me.flatMap(\.samples).count == 9_600)
    }
}
