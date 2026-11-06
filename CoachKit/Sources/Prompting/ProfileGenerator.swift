import ClaudeSession
import Foundation

/// Fait écrire par Claude le prompt d'un nouveau profil et les rubriques de son playbook, à partir d'une description
/// de la situation.
public struct ProfileGenerator: Sendable {
    /// Modèle le plus capable : la génération est rare et sa durée ne gêne aucun call.
    static let model = "opus"

    /// Consignes du générateur : ce qu'il doit écrire, et sous quelle forme.
    private let instructions: String

    public init(instructions: String) {
        self.instructions = instructions
    }

    /// Prompt et playbook de départ d'un profil adapté à `description` (« entretien technique pour un poste de
    /// développeur iOS », par exemple). Prend une trentaine de secondes.
    public func generate(description: String) async throws(PromptingError) -> ProfileContent {
        let completion = ClaudeCompletion(options: ClaudeSessionOptions(model: Self.model, systemPrompt: instructions))
        let response: String
        do {
            response = try await completion.complete(description)
        } catch {
            fatalError("TODO couche Erreurs")
        }
        return try Self.content(from: response)
    }

    /// Contenu du profil lu dans la réponse de Claude : le texte des blocs `<prompt>` et `<playbook>`.
    static func content(from response: String) throws(PromptingError) -> ProfileContent {
        guard let prompt = block(named: "prompt", in: response), let playbook = block(named: "playbook", in: response) else {
            fatalError("TODO couche Erreurs")
        }
        return ProfileContent(prompt: prompt, playbook: playbook)
    }

    /// Texte entre `<name>` et `</name>`, sans les lignes vides autour ; `nil` si le bloc manque.
    private static func block(named name: String, in response: String) -> String? {
        guard let start = response.range(of: "<\(name)>"),
              let end = response.range(of: "</\(name)>", range: start.upperBound..<response.endIndex)
        else { return nil }
        return response[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
