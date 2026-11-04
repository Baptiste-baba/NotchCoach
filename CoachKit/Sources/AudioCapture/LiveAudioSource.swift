import AVFoundation

/// Audio d'un vrai call : le micro pour « moi », l'audio du système pour le prospect.
public actor LiveAudioSource: AudioSource {
    /// Coupures des deux captures que leur relance n'a pas réparées.
    public nonisolated let failures: AsyncStream<AudioCaptureError>
    private let failuresContinuation: AsyncStream<AudioCaptureError>.Continuation
    private let mic: MicCapture
    private let systemAudio: SystemAudioCapture

    public init() {
        (failures, failuresContinuation) = AsyncStream.makeStream()
        mic = MicCapture(failures: failuresContinuation)
        systemAudio = SystemAudioCapture(failures: failuresContinuation)
    }

    public nonisolated func chunks(of speaker: Speaker) -> AsyncStream<AudioChunk> {
        switch speaker {
        case .me: mic.chunks
        case .prospect: systemAudio.chunks
        }
    }

    /// Démarre les deux captures, avec le même instant zéro. Si l'une échoue, aucune ne reste allumée.
    public func start() async throws(AudioCaptureError) {
        let origin = AVAudioTime.seconds(forHostTime: mach_absolute_time())
        do {
            try await systemAudio.start(origin: origin)
            try await mic.start(origin: origin)
        } catch {
            await stop()
            throw error
        }
    }

    public func stop() async {
        await mic.stop()
        await systemAudio.stop()
        failuresContinuation.finish()
    }
}
