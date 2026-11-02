import FluidAudio
import os

/// Modèles Parakeet Ultra et Silero VAD : téléchargés une fois depuis Hugging Face à une révision figée,
/// chargés une seule fois et partagés par les moteurs des deux canaux.
public actor ParakeetModels {
    private var preparation: Task<LoadedModels, any Error>?

    public init() {}

    /// Télécharge les modèles s'ils ne sont pas sur le disque, puis les charge. Le flux donne l'avancement, puis se
    /// termine quand les modèles sont prêts, ou sur une `TranscriptionError` : dans un seul flux, aucun avancement ne
    /// peut arriver après le résultat. Les appels suivants réutilisent les modèles chargés ; après un échec, un nouvel
    /// appel réessaie.
    public nonisolated func prepare() -> AsyncThrowingStream<ModelLoadState, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    _ = try await self.loaded { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Modèles chargés, pour les moteurs. Prépare les modèles s'ils ne le sont pas encore ; `progress` reçoit
    /// l'avancement quand c'est cet appel qui lance la préparation.
    func loaded(
        progress: @escaping @Sendable (ModelLoadState) -> Void = { _ in }
    ) async throws(TranscriptionError) -> LoadedModels {
        let task: Task<LoadedModels, any Error>
        if let preparation {
            task = preparation
        } else {
            task = Task { try await load(progress: progress) }
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

    private func load(progress: @escaping @Sendable (ModelLoadState) -> Void) async throws -> LoadedModels {
        for pin in [ModelPin.parakeetUltra, ModelPin.sileroVAD] {
            ModelRegistry.revisionOverrides[pin.repository] = pin.revision
        }
        // Le VAD pèse quelques Mo : chargé en parallèle, seul le téléchargement de Parakeet est suivi.
        async let vad = VadManager()
        let asrModels = try await AsrModels.downloadAndLoad(version: .ultra) { downloadProgress in
            progress(Self.loadState(for: downloadProgress))
        }
        return try await LoadedModels(asr: AsrManager(models: asrModels), vad: vad)
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
