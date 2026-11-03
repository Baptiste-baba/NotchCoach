/// Audio d'un vrai call : le micro pour « moi », l'audio du système pour le prospect.
public actor LiveAudioSource: AudioSource {
    private let mic = MicCapture()
    private let systemAudio = SystemAudioCapture()

    public init() {}

    public nonisolated func chunks(of speaker: Speaker) -> AsyncStream<AudioChunk> {
        switch speaker {
        case .me: mic.chunks
        case .prospect: systemAudio.chunks
        }
    }

    /// Démarre les deux captures, avec le même instant zéro.
    public func start() async throws(AudioCaptureError) {
        fatalError("TODO")
    }

    public func stop() async {
        fatalError("TODO")
    }
}
