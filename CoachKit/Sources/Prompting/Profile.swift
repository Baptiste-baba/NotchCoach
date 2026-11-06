import Foundation

/// Profil de coaching : un nom, un prompt (le rôle de Claude et le format de ses réponses) et un playbook (les
/// informations de l'utilisateur). L'utilisateur choisit le profil actif avant chaque call.
public struct Profile: Equatable, Hashable, Identifiable, Sendable {
    /// Bien plus que les quelques centaines de mots d'un prompt : au-delà, il ralentirait chaque suggestion.
    public static let maximumPromptLength = 20_000

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

    /// Lit le prompt du profil. Sans lui, Claude ne saurait pas quel rôle jouer : il ne peut être ni vide, ni ignoré.
    public func loadPrompt() throws(PromptingError) -> String {
        let prompt: String
        do {
            prompt = try MarkdownFileReader.read(promptURL, maximumLength: Self.maximumPromptLength)
        } catch {
            switch error {
            case .unreadable(let reason):
                throw .promptUnreadable(profile: name, reason: reason)
            case .notUTF8:
                throw .promptNotUTF8(profile: name)
            case .tooLong(let characterCount):
                throw .promptTooLong(profile: name, characterCount: characterCount, limit: Self.maximumPromptLength)
            }
        }
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw .promptEmpty(profile: name)
        }
        return prompt
    }

    /// Playbook du profil, recréé vide s'il a été supprimé : ses rubriques d'origine ne sont plus connues.
    public var playbookFile: PlaybookFile {
        PlaybookFile(url: playbookURL, template: "")
    }
}
