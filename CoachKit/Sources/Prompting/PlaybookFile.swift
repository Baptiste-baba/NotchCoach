import Foundation

/// Fichier Markdown du playbook, éditable par l'utilisateur. Créé depuis un modèle à remplir s'il n'existe pas encore.
public struct PlaybookFile: Equatable, Sendable {
    /// `~/Library/Application Support/NotchCoach/playbook.md` : l'app n'est pas sandboxée.
    public static let standardURL = URL.applicationSupportDirectory.appending(components: "NotchCoach", "playbook.md")
    /// Environ 20 pages. Au-delà, le playbook ralentirait chaque suggestion.
    public static let maximumLength = 50_000

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
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw .playbookUnreadable(reason: error.localizedDescription)
        }
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw .playbookNotUTF8
        }
        guard markdown.count <= Self.maximumLength else {
            throw .playbookTooLong(characterCount: markdown.count, limit: Self.maximumLength)
        }
        return Playbook(markdown: markdown)
    }
}
