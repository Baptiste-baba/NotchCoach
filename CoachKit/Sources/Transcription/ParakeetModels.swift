import FluidAudio

/// Modèles Parakeet Ultra et Silero VAD : téléchargés une fois depuis Hugging Face à une révision figée,
/// chargés une seule fois et partagés par les moteurs des deux canaux.
public actor ParakeetModels {
    /// Avancement de la préparation, à afficher dans l'UI.
    public nonisolated let loadStates: AsyncStream<ModelLoadState>
    private let loadStatesContinuation: AsyncStream<ModelLoadState>.Continuation

    public init() {
        (loadStates, loadStatesContinuation) = AsyncStream.makeStream()
    }

    /// Télécharge les modèles s'ils ne sont pas sur le disque, puis les charge. Les appels suivants réutilisent
    /// les modèles déjà chargés.
    public func prepare() async throws {
        fatalError("TODO")
    }

    /// Modèles chargés, pour les moteurs. Prépare les modèles s'ils ne le sont pas encore.
    func loaded() async throws -> LoadedModels {
        fatalError("TODO")
    }
}

/// Modèles FluidAudio prêts à l'emploi.
struct LoadedModels: Sendable {
    let asr: AsrModels
    let vad: VadManager
}
