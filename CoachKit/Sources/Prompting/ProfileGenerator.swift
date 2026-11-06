import ClaudeSession

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
        fatalError("TODO")
    }

    /// Contenu du profil lu dans la réponse de Claude.
    static func content(from response: String) throws(PromptingError) -> ProfileContent {
        fatalError("TODO")
    }
}
