import Foundation

/// Fichier Markdown du playbook, éditable par l'utilisateur. Créé depuis un modèle à remplir s'il n'existe pas encore.
public struct PlaybookFile: Equatable, Sendable {
    /// `~/Library/Application Support/NotchCoach/playbook.md` : l'app n'est pas sandboxée.
    public static let standardURL = URL.applicationSupportDirectory.appending(components: "NotchCoach", "playbook.md")

    /// Emplacement du fichier.
    public let url: URL
    /// Contenu du fichier à sa création : les rubriques vides, à remplir.
    let template: String

    public init(url: URL = PlaybookFile.standardURL, template: String) {
        self.url = url
        self.template = template
    }

    /// Crée le fichier depuis le modèle, et son dossier, s'il n'existe pas encore. Un fichier existant n'est jamais
    /// modifié.
    public func createIfMissing() throws {
        fatalError("TODO")
    }

    /// Lit le playbook, après avoir créé le fichier s'il n'existe pas encore.
    public func load() throws -> Playbook {
        fatalError("TODO")
    }
}
