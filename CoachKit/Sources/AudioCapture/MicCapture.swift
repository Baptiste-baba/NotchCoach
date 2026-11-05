import AVFoundation

/// Capture du micro avec `AVAudioEngine` : la voix de l'utilisateur, convertie en 16 kHz mono. Quand le micro change
/// (écouteurs branchés, par exemple), `AVAudioEngine` s'arrête sans redémarrer seul : la capture repart sur le
/// nouveau micro, avec un moteur neuf.
actor MicCapture {
    /// Audio du micro. Le flux se termine à l'arrêt.
    nonisolated let chunks: AsyncStream<AudioChunk>
    private let continuation: AsyncStream<AudioChunk>.Continuation
    /// Coupures que la relance n'a pas réparées.
    private let failures: AsyncStream<AudioCaptureError>.Continuation
    /// Moteur de la dernière tentative de démarrage, réussie ou non : `nil` avant le démarrage et après l'arrêt. Chaque
    /// tentative en crée un neuf, car un moteur réutilisé après un changement d'appareil annonce encore l'ancien
    /// format du micro.
    private var engine: AVAudioEngine?
    /// Instant zéro du call, en secondes de l'horloge hôte.
    private var origin: TimeInterval = 0
    private var configurationObserver: (any NSObjectProtocol)?
    /// Signalement de la dernière relance ratée, en attente de `failureGracePeriod`.
    private var pendingFailureReport: Task<Void, Never>?
    /// Une capture ne sert qu'une fois : après `stop()`, `start()` n'a plus d'effet.
    private var isStopped = false

    /// Délai avant de signaler une relance ratée : le temps que le nouvel appareil se stabilise.
    private static let failureGracePeriod: Duration = .seconds(2)

    init(failures: AsyncStream<AudioCaptureError>.Continuation) {
        (chunks, continuation) = AsyncStream.makeStream()
        self.failures = failures
    }

    /// Démarre la capture, après avoir demandé l'accès au micro s'il ne l'a jamais été. `origin` : instant zéro du
    /// call, en secondes de l'horloge hôte.
    func start(origin: TimeInterval) async throws(AudioCaptureError) {
        guard engine == nil, !isStopped else { return }
        try await Self.requireAccess()
        // Arrêté, ou déjà démarré, pendant la demande d'accès : rien à faire.
        guard engine == nil, !isStopped else { return }
        self.origin = origin
        do {
            try startEngine()
        } catch {
            stopEngine()
            throw error
        }
    }

    func stop() {
        isStopped = true
        stopEngine()
        continuation.finish()
    }

    /// Le micro a changé : la capture repart sur le nouveau, avec son format. En cas d'échec, le prochain changement
    /// (retour des écouteurs, par exemple) relance une nouvelle tentative : le moteur qui n'a pas démarré reçoit lui
    /// aussi la notification.
    private func restart() {
        guard engine != nil, !isStopped else { return }
        stopEngine()
        do {
            try startEngine()
            logger.notice("Micro relancé après un changement d'appareil")
        } catch {
            logger.error("Micro coupé après un changement d'appareil : \(error.localizedDescription, privacy: .public)")
            reportUnlessRecovered(error)
        }
    }

    /// Pendant un changement d'appareil, macOS passe par des formats transitoires (micro à 0 Hz, par exemple) : les
    /// premières relances échouent, puis une suivante réussit, en moins d'une seconde. Une coupure n'est donc signalée
    /// que si le micro est toujours arrêté après `failureGracePeriod`.
    private func reportUnlessRecovered(_ error: AudioCaptureError) {
        pendingFailureReport?.cancel()
        pendingFailureReport = Task { [weak self] in
            try? await Task.sleep(for: Self.failureGracePeriod)
            guard !Task.isCancelled else { return }
            await self?.reportIfStillDown(error)
        }
    }

    private func reportIfStillDown(_ error: AudioCaptureError) {
        guard !isStopped, engine?.isRunning != true else { return }
        failures.yield(error)
    }

    /// Démarre la capture sur un moteur neuf, surveillé dès sa création : même s'il ne démarre pas, le prochain
    /// changement d'appareil relance une tentative.
    private func startEngine() throws(AudioCaptureError) {
        let engine = AVAudioEngine()
        self.engine = engine
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.restart() }
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw .microphoneUnavailable(reason: "aucun micro n'est disponible.")
        }
        // Garde-fou : avec un format qui ne correspond pas à celui du micro, `installTap` lève une exception
        // Objective-C, que Swift ne peut pas rattraper, et l'app plante.
        guard format.sampleRate == input.inputFormat(forBus: 0).sampleRate else {
            throw .microphoneUnavailable(reason: "le format du micro est en train de changer.")
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
            throw .microphoneUnavailable(reason: error.localizedDescription)
        }
    }

    /// Arrête le moteur et cesse de le surveiller. Sans effet si aucun moteur n'existe.
    private func stopEngine() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
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
