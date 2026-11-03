import AVFoundation
import ScreenCaptureKit

/// Capture de l'audio du système avec ScreenCaptureKit, sans celui de l'app : la voix du prospect. ScreenCaptureKit
/// le fournit déjà en 16 kHz mono ; le convertisseur garantit ce format quoi qu'il arrive.
actor SystemAudioCapture {
    /// Audio du système. Le flux se termine à l'arrêt.
    nonisolated let chunks: AsyncStream<AudioChunk>
    private let continuation: AsyncStream<AudioChunk>.Continuation
    private var stream: SCStream?
    /// Gardée ici : le flux ne retient pas ses sorties.
    private var output: AudioOutput?
    /// Une capture ne sert qu'une fois : après `stop()`, `start()` n'a plus d'effet, même arrivé pendant le démarrage.
    private var isStopped = false

    init() {
        (chunks, continuation) = AsyncStream.makeStream()
    }

    /// Démarre la capture. `origin` : instant zéro du call, en secondes de l'horloge hôte.
    func start(origin: TimeInterval) async throws(AudioCaptureError) {
        guard stream == nil, !isStopped else { return }
        guard let content = try? await SCShareableContent.current, let display = content.displays.first else { return }
        guard !isStopped else { return }
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = AudioChunk.sampleRate
        configuration.channelCount = 1
        // Seul l'audio sert, mais un flux capture toujours l'écran : la vidéo est réduite au minimum.
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        let stream = SCStream(
            filter: SCContentFilter(display: display, excludingWindows: []),
            configuration: configuration,
            delegate: nil
        )
        let output = AudioOutput(origin: origin, continuation: continuation)
        do {
            // Les images aussi passent par cette sortie, qui les ignore : sans sortie, le flux les signale
            // une à une dans le journal.
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: output.queue)
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: output.queue)
            try await stream.startCapture()
        } catch {
            return
        }
        guard !isStopped else {
            try? await stream.stopCapture()
            return
        }
        self.stream = stream
        self.output = output
    }

    func stop() async {
        isStopped = true
        try? await stream?.stopCapture()
        stream = nil
        output = nil
        continuation.finish()
    }
}

/// Reçoit les buffers du flux, convertit l'audio et le date depuis l'instant zéro du call.
private final class AudioOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    /// File série : les buffers arrivent un par un, et l'état ci-dessous n'est touché que sur elle.
    let queue = DispatchQueue(label: "io.github.baptiste-baba.NotchCoach.SystemAudioCapture")
    private let origin: TimeInterval
    private let continuation: AsyncStream<AudioChunk>.Continuation
    private var resampler: MonoResampler?
    private var resamplerFormat: AVAudioFormat?

    init(origin: TimeInterval, continuation: AsyncStream<AudioChunk>.Continuation) {
        self.origin = origin
        self.continuation = continuation
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, let buffer = Self.pcmBuffer(from: sampleBuffer) else { return }
        if resamplerFormat != buffer.format {
            resampler = MonoResampler(from: buffer.format)
            resamplerFormat = buffer.format
        }
        guard let samples = resampler?.convert(buffer), !samples.isEmpty else { return }
        // Horodatage sur l'horloge hôte, la même que celle de `origin`.
        let startTime = sampleBuffer.presentationTimeStamp.seconds - origin
        continuation.yield(AudioChunk(samples: samples, startTime: startTime))
    }

    private static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let description = sampleBuffer.formatDescription else { return nil }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleBuffer.numSamples)) else {
            return nil
        }
        buffer.frameLength = buffer.frameCapacity
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(sampleBuffer.numSamples),
            into: buffer.mutableAudioBufferList
        )
        return status == noErr ? buffer : nil
    }
}
