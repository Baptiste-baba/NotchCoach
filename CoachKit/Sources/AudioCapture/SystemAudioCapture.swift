import AVFoundation
import CoreGraphics
import ScreenCaptureKit

/// Capture de l'audio du système avec ScreenCaptureKit, sans celui de l'app : la voix du prospect. ScreenCaptureKit
/// le fournit déjà en 16 kHz mono ; le convertisseur garantit ce format quoi qu'il arrive. Si le flux s'arrête de
/// lui-même (écran débranché, par exemple), un nouveau flux le remplace.
actor SystemAudioCapture {
    /// Audio du système. Le flux se termine à l'arrêt.
    nonisolated let chunks: AsyncStream<AudioChunk>
    private let continuation: AsyncStream<AudioChunk>.Continuation
    /// Coupures que la relance n'a pas réparées.
    private let failures: AsyncStream<AudioCaptureError>.Continuation
    /// Instant zéro du call, en secondes de l'horloge hôte.
    private var origin: TimeInterval = 0
    private var stream: SCStream?
    /// Gardée ici : le flux ne retient pas ses sorties.
    private var output: AudioOutput?
    /// Une capture ne sert qu'une fois : après `stop()`, `start()` n'a plus d'effet, même arrivé pendant le démarrage.
    private var isStopped = false

    init(failures: AsyncStream<AudioCaptureError>.Continuation) {
        (chunks, continuation) = AsyncStream.makeStream()
        self.failures = failures
    }

    /// Démarre la capture. `origin` : instant zéro du call, en secondes de l'horloge hôte.
    func start(origin: TimeInterval) async throws(AudioCaptureError) {
        guard stream == nil, !isStopped else { return }
        self.origin = origin
        try await startStream()
    }

    func stop() async {
        isStopped = true
        try? await stream?.stopCapture()
        stream = nil
        output = nil
        continuation.finish()
    }

    /// Le flux s'est arrêté sans qu'on le demande : un nouveau le remplace, avec le même instant zéro.
    private func restart(after error: any Error) async {
        guard stream != nil, !isStopped else { return }
        stream = nil
        output = nil
        logger.notice("Audio du Mac interrompu, relance : \(error.localizedDescription, privacy: .public)")
        do {
            try await startStream()
        } catch {
            logger.error("Audio du Mac coupé : \(error.localizedDescription, privacy: .public)")
            failures.yield(error)
        }
    }

    private func startStream() async throws(AudioCaptureError) {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            // Sans l'autorisation d'enregistrer l'écran, ScreenCaptureKit ne dit pas mieux qu'un refus.
            throw CGPreflightScreenCaptureAccess()
                ? .systemAudioUnavailable(reason: error.localizedDescription)
                : .screenRecordingDenied
        }
        guard let display = content.displays.first else {
            throw .systemAudioUnavailable(reason: "aucun écran n'est disponible.")
        }
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
        let output = AudioOutput(origin: origin, continuation: continuation) { [weak self] error in
            Task { await self?.restart(after: error) }
        }
        let stream = SCStream(
            filter: SCContentFilter(display: display, excludingWindows: []),
            configuration: configuration,
            delegate: output
        )
        do {
            // Les images aussi passent par cette sortie, qui les ignore : sans sortie, le flux les signale
            // une à une dans le journal.
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: output.queue)
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: output.queue)
            try await stream.startCapture()
        } catch {
            throw .systemAudioUnavailable(reason: error.localizedDescription)
        }
        guard !isStopped else {
            try? await stream.stopCapture()
            return
        }
        self.stream = stream
        self.output = output
    }
}

/// Reçoit les buffers du flux, convertit l'audio et le date depuis l'instant zéro du call. Signale aussi l'arrêt du
/// flux sur une erreur.
private final class AudioOutput: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    /// File série : les buffers arrivent un par un, et l'état ci-dessous n'est touché que sur elle.
    let queue = DispatchQueue(label: "io.github.baptiste-baba.NotchCoach.SystemAudioCapture")
    private let origin: TimeInterval
    private let continuation: AsyncStream<AudioChunk>.Continuation
    private let onStop: @Sendable (any Error) -> Void
    private var resampler: MonoResampler?
    private var resamplerFormat: AVAudioFormat?

    init(
        origin: TimeInterval,
        continuation: AsyncStream<AudioChunk>.Continuation,
        onStop: @escaping @Sendable (any Error) -> Void
    ) {
        self.origin = origin
        self.continuation = continuation
        self.onStop = onStop
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

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        onStop(error)
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
