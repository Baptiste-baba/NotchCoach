/// Révision figée d'un dépôt de modèles Hugging Face : la branche `main`, utilisée par défaut, peut changer à tout moment.
struct ModelPin: Equatable, Sendable {
    let repository: String
    let revision: String

    // Révisions relevées le 31/10/2026 via l'API Hugging Face.
    static let parakeetUltra = ModelPin(
        repository: "FluidInference/parakeet-ultra-coreml",
        revision: "95eaa59a39d4394f047a4dc5cce480388a60d1b6"
    )
    static let sileroVAD = ModelPin(
        repository: "FluidInference/silero-vad-coreml",
        revision: "b419383c55c110e2c9271fa6ee0ea83d03c70d96"
    )
}
