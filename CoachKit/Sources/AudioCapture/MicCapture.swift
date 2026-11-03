import AVFoundation

/// Capture du micro avec `AVAudioEngine` : la voix de l'utilisateur, convertie en 16 kHz mono.
actor MicCapture {
    /// Audio du micro. Le flux se termine à l'arrêt.
    nonisolated let chunks: AsyncStream<AudioChunk>
    private let continuation: AsyncStream<AudioChunk>.Continuation
    private var engine: AVAudioEngine?
    /// Une capture ne sert qu'une fois : après `stop()`, `start()` n'a plus d'effet.
    private var isStopped = false

    init() {
        (chunks, continuation) = AsyncStream.makeStream()
    }

    /// Démarre la capture. `origin` : instant zéro du call, en secondes de l'horloge hôte.
    func start(origin: TimeInterval) throws(AudioCaptureError) {
        guard engine == nil, !isStopped else { return }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard let resampler = MonoResampler(from: format) else { return }
        let continuation = continuation
        // Appelé sur un thread audio, un buffer après l'autre : le convertisseur n'est jamais utilisé en parallèle.
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, time in
            let samples = resampler.convert(buffer)
            guard !samples.isEmpty else { return }
            let startTime = AVAudioTime.seconds(forHostTime: time.hostTime) - origin
            continuation.yield(AudioChunk(samples: samples, startTime: startTime))
        }
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            return
        }
        self.engine = engine
    }

    func stop() {
        isStopped = true
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        engine = nil
        continuation.finish()
    }
}
