import AVFoundation

/// Capture du micro avec `AVAudioEngine` : la voix de l'utilisateur, convertie en 16 kHz mono. Quand le micro change
/// (écouteurs branchés, par exemple), `AVAudioEngine` s'arrête sans redémarrer seul : la capture repart sur le
/// nouveau micro.
actor MicCapture {
    /// Audio du micro. Le flux se termine à l'arrêt.
    nonisolated let chunks: AsyncStream<AudioChunk>
    private let continuation: AsyncStream<AudioChunk>.Continuation
    /// Coupures que la relance n'a pas réparées.
    private let failures: AsyncStream<AudioCaptureError>.Continuation
    private let engine = AVAudioEngine()
    /// Instant zéro du call, en secondes de l'horloge hôte.
    private var origin: TimeInterval = 0
    private var configurationObserver: (any NSObjectProtocol)?
    private var isRunning = false
    /// Une capture ne sert qu'une fois : après `stop()`, `start()` n'a plus d'effet.
    private var isStopped = false

    init(failures: AsyncStream<AudioCaptureError>.Continuation) {
        (chunks, continuation) = AsyncStream.makeStream()
        self.failures = failures
    }

    /// Démarre la capture, après avoir demandé l'accès au micro s'il ne l'a jamais été. `origin` : instant zéro du
    /// call, en secondes de l'horloge hôte.
    func start(origin: TimeInterval) async throws(AudioCaptureError) {
        guard !isRunning, !isStopped else { return }
        try await Self.requireAccess()
        // Arrêté pendant la demande d'accès : la capture ne démarre pas.
        guard !isStopped else { return }
        self.origin = origin
        try startEngine()
        isRunning = true
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.restart() }
        }
    }

    func stop() {
        isStopped = true
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        isRunning = false
        continuation.finish()
    }

    /// Le micro a changé : la capture repart sur le nouveau, avec son format. En cas d'échec, la coupure est signalée,
    /// et le prochain changement (retour des écouteurs, par exemple) relance une nouvelle tentative.
    private func restart() {
        guard isRunning, !isStopped else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        do {
            try startEngine()
            logger.notice("Micro relancé après un changement d'appareil")
        } catch {
            logger.error("Micro coupé après un changement d'appareil : \(error.localizedDescription, privacy: .public)")
            failures.yield(error)
        }
    }

    private func startEngine() throws(AudioCaptureError) {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw .microphoneUnavailable(reason: "aucun micro n'est disponible.")
        }
        guard let resampler = MonoResampler(from: format) else {
            throw .microphoneUnavailable(reason: "le format du micro n'est pas pris en charge.")
        }
        let continuation = continuation
        let origin = origin
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
            throw .microphoneUnavailable(reason: error.localizedDescription)
        }
    }

    /// Sans accès, `AVAudioEngine` capte du silence sans rien signaler : l'accès est vérifié avant de démarrer.
    private static func requireAccess() async throws(AudioCaptureError) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .audio) else { throw .microphoneDenied }
        default:
            throw .microphoneDenied
        }
    }
}
