import Foundation

/// Prompts livrés dans l'app, chacun dans son fichier Markdown : jamais en dur dans la logique.
enum BundledPrompt {
    /// Texte du fichier `<name>.md` des ressources de l'app, ou une chaîne vide s'il manque.
    static func text(named name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }
}
