import AVFoundation
import Testing
@testable import AudioCapture

/// Buffer Float32 non entrelacé, comme ceux du micro : chaque canal garde une valeur constante, dans l'ordre de
/// `channelValues`.
private func buffer(sampleRate: Double, frameCount: Int, channelValues: [Float]) throws -> AVAudioPCMBuffer {
    let format = try #require(AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: AVAudioChannelCount(channelValues.count),
        interleaved: false
    ))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)))
    buffer.frameLength = AVAudioFrameCount(frameCount)
    let channels = try #require(buffer.floatChannelData)
    for (channel, value) in channelValues.enumerated() {
        channels[channel].update(repeating: value, count: frameCount)
    }
    return buffer
}

struct MonoResamplerTests {
    @Test func losesNothingFromABufferLargerThanTheConverterReadsAtOnce() throws {
        // Une seconde à 48 kHz, la fréquence du micro d'un MacBook. Le convertisseur n'en lit que 4 096 images à la
        // fois : sans découpage, le reste serait perdu.
        let input = try buffer(sampleRate: 48_000, frameCount: 48_000, channelValues: [0.5])
        let resampler = try #require(MonoResampler(from: input.format))

        let samples = resampler.convert(input)

        // 16 000 échantillons, à ceux près que le filtre garde pour le buffer suivant.
        #expect(abs(samples.count - 16_000) < 10)
    }

    @Test func keepsConvertingBufferAfterBuffer() throws {
        // 100 ms à 48 kHz, la taille des buffers du micro.
        let input = try buffer(sampleRate: 48_000, frameCount: 4_800, channelValues: [0.5])
        let resampler = try #require(MonoResampler(from: input.format))

        // Un convertisseur qui se croirait en fin de flux ne rendrait plus rien après le premier buffer.
        for _ in 0..<5 {
            #expect(abs(resampler.convert(input).count - 1_600) < 10)
        }
    }

    @Test func keepsTheLevelOfTheSignal() throws {
        let input = try buffer(sampleRate: 48_000, frameCount: 4_800, channelValues: [0.5])
        let resampler = try #require(MonoResampler(from: input.format))

        // Le premier buffer amorce le filtre ; ensuite, un signal constant garde sa valeur.
        _ = resampler.convert(input)
        let samples = resampler.convert(input)

        #expect(samples.allSatisfy { abs($0 - 0.5) < 0.01 })
    }

    @Test func mixesTheChannelsInsteadOfKeepingTheFirst() throws {
        // Seul le second canal a du signal : en ne gardant que le premier, la sortie serait silencieuse.
        let input = try buffer(sampleRate: 48_000, frameCount: 4_800, channelValues: [0, 0.5])
        let resampler = try #require(MonoResampler(from: input.format))

        _ = resampler.convert(input)
        let samples = resampler.convert(input)

        #expect(!samples.isEmpty)
        #expect(samples.allSatisfy { $0 > 0.1 })
    }

    @Test func audioAlreadyAt16kHzMonoIsUnchanged() throws {
        // Le format que ScreenCaptureKit fournit pour l'audio du système.
        let input = try buffer(sampleRate: 16_000, frameCount: 320, channelValues: [0.25])
        let resampler = try #require(MonoResampler(from: input.format))

        let samples = resampler.convert(input)

        #expect(samples == [Float](repeating: 0.25, count: 320))
    }
}
