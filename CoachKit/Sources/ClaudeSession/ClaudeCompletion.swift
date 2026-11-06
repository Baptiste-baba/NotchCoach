import Foundation

/// Requête unique au CLI `claude` : un process lancé pour une seule réponse, qui se termine ensuite. Même isolation que
/// la session des calls (voir la section Sécurité du CLAUDE.md). Sert quand la latence ne compte pas, comme pour écrire
/// le prompt d'un nouveau profil.
public struct ClaudeCompletion: Sendable {
    private let options: ClaudeSessionOptions

    public init(options: ClaudeSessionOptions) {
        self.options = options
    }

    /// Envoie `input` sur stdin et renvoie la réponse complète de Claude. L'annulation de la tâche arrête le process.
    public func complete(_ input: String) async throws -> String {
        fatalError("TODO")
    }
}
