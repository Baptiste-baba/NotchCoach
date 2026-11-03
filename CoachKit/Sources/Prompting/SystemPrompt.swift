import Foundation

/// System prompt de la session Claude : les consignes du coach, avec le playbook à l'emplacement prévu. Logique pure.
public enum SystemPrompt {
    /// Emplacement du playbook dans les consignes du coach.
    static let playbookPlaceholder = "{{playbook}}"

    /// Consignes du coach (`instructions`), où `{{playbook}}` est remplacé par le contenu du playbook. Sans cet
    /// emplacement, le playbook est ajouté à la fin : il n'est jamais perdu.
    public static func text(instructions: String, playbook: Playbook) -> String {
        let markdown = playbook.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard instructions.contains(playbookPlaceholder) else {
            return instructions + "\n\n" + markdown
        }
        return instructions.replacingOccurrences(of: playbookPlaceholder, with: markdown)
    }
}
