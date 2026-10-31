/// Demande de suggestion envoyée à la session. Les identifiants sont croissants : une réponse dont
/// l'identifiant n'est plus le dernier envoyé est obsolète et n'est plus émise.
public struct LLMRequest: Equatable, Sendable {
    public var id: Int
    public var prompt: String

    public init(id: Int, prompt: String) {
        self.id = id
        self.prompt = prompt
    }
}
