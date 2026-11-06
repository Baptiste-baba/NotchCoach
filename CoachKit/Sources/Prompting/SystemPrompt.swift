import Foundation

/// System prompt de la session Claude : la partie technique fournie par l'app, avec le prompt et le playbook du profil
/// à leurs emplacements. Logique pure.
public enum SystemPrompt {
    /// Emplacement du prompt du profil dans la partie technique.
    static let promptPlaceholder = "{{prompt}}"
    /// Emplacement du playbook dans la partie technique.
    static let playbookPlaceholder = "{{playbook}}"

    /// System prompt d'un call : la partie technique fournie par l'app (`frame`), où `{{prompt}}` est remplacé par le
    /// prompt du profil et `{{playbook}}` par son playbook. Seule la partie technique est lue : un emplacement écrit
    /// dans le prompt ou le playbook reste tel quel.
    public static func text(frame: String, prompt: String, playbook: Playbook) -> String {
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let playbook = playbook.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        // Le prompt est inséré dans les morceaux de la partie technique, avant que le playbook ne les relie.
        return frame
            .components(separatedBy: playbookPlaceholder)
            .map { $0.replacingOccurrences(of: promptPlaceholder, with: prompt) }
            .joined(separator: playbook)
    }
}
