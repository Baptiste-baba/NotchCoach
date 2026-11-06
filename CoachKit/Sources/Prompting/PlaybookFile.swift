import Foundation

/// Fichier Markdown du playbook, éditable par l'utilisateur. Créé depuis un modèle à remplir s'il n'existe pas encore.
public struct PlaybookFile: Equatable, Sendable {
    /// Environ 20 pages. Au-delà, le playbook ralentirait chaque suggestion.
    public static let maximumLength = 50_000

    /// Emplacement du fichier.
    public let url: URL
    /// Contenu du fichier à sa création : les rubriques vides, à remplir.
    let template: String

    public init(url: URL, template: String) {
        self.url = url
        self.template = template
    }

    /// Crée le fichier depuis le modèle, et son dossier, s'il n'existe pas encore. Un fichier existant n'est jamais
    /// modifié.
    public func createIfMissing() throws(PromptingError) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(template.utf8).write(to: url, options: .withoutOverwriting)
        } catch {
            throw .playbookCreationFailed(reason: error.localizedDescription)
        }
    }

    /// Lit le playbook, après avoir créé le fichier s'il n'existe pas encore.
    public func load() throws(PromptingError) -> Playbook {
        try createIfMissing()
        do {
            return Playbook(markdown: try MarkdownFileReader.read(url, maximumLength: Self.maximumLength))
        } catch {
            switch error {
            case .unreadable(let reason):
                throw .playbookUnreadable(reason: reason)
            case .notUTF8:
                throw .playbookNotUTF8
            case .tooLong(let characterCount):
                throw .playbookTooLong(characterCount: characterCount, limit: Self.maximumLength)
            }
        }
    }
}
