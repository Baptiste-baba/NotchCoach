import Foundation

/// System prompt de la session Claude : les consignes du coach, avec le playbook à l'emplacement prévu. Logique pure.
public enum SystemPrompt {
    /// Emplacement du playbook dans les consignes du coach.
    static let playbookPlaceholder = "{{playbook}}"

    /// Consignes du coach (`instructions`), où `{{playbook}}` est remplacé par le contenu du playbook.
    public static func text(instructions: String, playbook: Playbook) -> String {
        let markdown = playbook.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        return instructions.replacingOccurrences(of: playbookPlaceholder, with: markdown)
    }
}
