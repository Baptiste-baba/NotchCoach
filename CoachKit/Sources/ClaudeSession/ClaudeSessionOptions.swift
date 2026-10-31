import Foundation

/// Réglages de la session fournis par l'app.
public struct ClaudeSessionOptions: Equatable, Sendable {
    /// Alias ou nom complet du modèle, passé à `--model`.
    public var model: String
    public var systemPrompt: String
    /// Chemin du binaire `claude` forcé dans les réglages ; `nil` pour le résoudre automatiquement.
    public var binaryPathOverride: URL?

    public init(model: String = "haiku", systemPrompt: String, binaryPathOverride: URL? = nil) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.binaryPathOverride = binaryPathOverride
    }
}
