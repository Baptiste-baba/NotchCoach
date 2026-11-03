import Foundation

/// Fichier Markdown du playbook, éditable par l'utilisateur : `~/Library/Application Support/NotchCoach/playbook.md`.
/// Créé depuis un modèle à remplir s'il n'existe pas encore.
public struct PlaybookFile: Equatable, Sendable {
    /// Emplacement du fichier.
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}
