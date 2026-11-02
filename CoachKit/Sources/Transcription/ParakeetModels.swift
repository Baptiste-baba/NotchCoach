import FluidAudio

/// Modèles Parakeet Ultra et Silero VAD : téléchargés une fois depuis Hugging Face à une révision figée,
/// chargés une seule fois et partagés par les moteurs des deux canaux.
public actor ParakeetModels {
    /// Avancement de la préparation, à afficher dans l'UI.
    public nonisolated let loadStates: AsyncStream<ModelLoadState>
    private let loadStatesContinuation: AsyncStream<ModelLoadState>.Continuation
    private var preparation: Task<LoadedModels, any Error>?

    public init() {
        (loadStates, loadStatesContinuation) = AsyncStream.makeStream()
    }

    /// Télécharge les modèles s'ils ne sont pas sur le disque, puis les charge. Les appels suivants réutilisent
    /// les modèles déjà chargés.
    public func prepare() async throws {
        _ = try await loaded()
    }

    /// Modèles chargés, pour les moteurs. Prépare les modèles s'ils ne le sont pas encore.
    func loaded() async throws -> LoadedModels {
        if let preparation {
            return try await preparation.value
        }
        let task = Task { try await load() }
        preparation = task
        return try await task.value
    }

    private func load() async throws -> LoadedModels {
        for pin in [ModelPin.parakeetUltra, ModelPin.sileroVAD] {
            ModelRegistry.revisionOverrides[pin.repository] = pin.revision
        }
        let states = loadStatesContinuation
        // Le VAD pèse quelques Mo : seul le téléchargement de Parakeet est suivi.
        let vad = try await VadManager()
        let asrModels = try await AsrModels.downloadAndLoad(version: .ultra) { progress in
            switch progress.phase {
            case .listing, .downloading:
                states.yield(.downloading(fraction: progress.fractionCompleted))
            case .compiling:
                states.yield(.loading)
            }
        }
        states.yield(.ready)
        return LoadedModels(asr: AsrManager(models: asrModels), vad: vad)
    }
}

/// Modèles FluidAudio prêts à l'emploi. Les deux managers sont des actors partagés par les moteurs des deux
/// canaux : chaque moteur garde son propre état de VAD et de décodage.
struct LoadedModels: Sendable {
    let asr: AsrManager
    let vad: VadManager
}
