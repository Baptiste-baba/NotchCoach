import FluidAudio
import os

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
    /// les modèles déjà chargés. Après un échec, un nouvel appel réessaie.
    public func prepare() async throws(TranscriptionError) {
        _ = try await loaded()
    }

    /// Modèles chargés, pour les moteurs. Prépare les modèles s'ils ne le sont pas encore.
    func loaded() async throws(TranscriptionError) -> LoadedModels {
        let task: Task<LoadedModels, any Error>
        if let preparation {
            task = preparation
        } else {
            task = Task { try await load() }
            preparation = task
        }
        do {
            return try await task.value
        } catch {
            // Les appels concurrents attendaient la même tâche : un seul l'oublie, le suivant relancera.
            if preparation == task {
                preparation = nil
            }
            logger.error("Préparation des modèles impossible : \(error.localizedDescription, privacy: .public)")
            throw .modelsUnavailable(reason: error.localizedDescription)
        }
    }

    private func load() async throws -> LoadedModels {
        for pin in [ModelPin.parakeetUltra, ModelPin.sileroVAD] {
            ModelRegistry.revisionOverrides[pin.repository] = pin.revision
        }
        let states = loadStatesContinuation
        // Le VAD pèse quelques Mo : seul le téléchargement de Parakeet est suivi.
        let vad = try await VadManager()
        let asrModels = try await AsrModels.downloadAndLoad(version: .ultra) { progress in
            states.yield(Self.loadState(for: progress))
        }
        states.yield(.ready)
        return LoadedModels(asr: AsrManager(models: asrModels), vad: vad)
    }

    /// Part de l'avancement que FluidAudio réserve au téléchargement d'un dépôt de modèles, la compilation
    /// occupant le reste (`ProgressReporter.downloadPhaseWeight` dans FluidAudio 0.18.0).
    static let downloadPhaseWeight = 0.5

    /// Traduit l'avancement de FluidAudio pour l'UI : le pourcentage ne couvre que le téléchargement, et des
    /// modèles déjà sur le disque (téléchargement terminé d'emblée) s'affichent comme un chargement.
    static func loadState(for progress: DownloadProgress) -> ModelLoadState {
        guard case .downloading = progress.phase else { return .loading }
        let fraction = min(max(progress.fractionCompleted / downloadPhaseWeight, 0), 1)
        return fraction < 1 ? .downloading(fraction: fraction) : .loading
    }
}

/// Modèles FluidAudio prêts à l'emploi. Les deux managers sont des actors partagés par les moteurs des deux
/// canaux : chaque moteur garde son propre état de VAD et de décodage.
struct LoadedModels: Sendable {
    let asr: AsrManager
    let vad: VadManager
}
