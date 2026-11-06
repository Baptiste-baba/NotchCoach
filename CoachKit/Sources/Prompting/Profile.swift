import Foundation

/// Profil de coaching : un nom, un prompt (le rôle de Claude et le format de ses réponses) et un playbook (les
/// informations de l'utilisateur). L'utilisateur choisit le profil actif avant chaque call.
public struct Profile: Equatable, Hashable, Identifiable, Sendable {
    /// Nom affiché dans le menu : c'est aussi celui de son dossier.
    public let name: String
    /// Dossier du profil, qui contient `prompt.md` et `playbook.md`.
    public let directory: URL

    init(name: String, directory: URL) {
        self.name = name
        self.directory = directory
    }

    public var id: String { name }

    /// Rôle de Claude, son objectif, le ton et le format des réponses : la partie du system prompt que l'utilisateur
    /// modifie.
    public var promptURL: URL { directory.appending(component: "prompt.md") }

    /// Informations de l'utilisateur, ajoutées au system prompt.
    public var playbookURL: URL { directory.appending(component: "playbook.md") }

    /// Lit le prompt du profil.
    public func loadPrompt() throws(PromptingError) -> String {
        guard let prompt = try? String(contentsOf: promptURL, encoding: .utf8) else {
            fatalError("TODO couche Erreurs")
        }
        return prompt
    }

    /// Playbook du profil, recréé vide s'il a été supprimé : ses rubriques d'origine ne sont plus connues.
    public var playbookFile: PlaybookFile {
        PlaybookFile(url: playbookURL, template: "")
    }
}
