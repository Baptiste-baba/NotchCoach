import ClaudeSession
import Foundation

/// Fait écrire par Claude le compte rendu d'un call, à partir de sa transcription et du profil utilisé.
public struct CallRecapGenerator: Sendable {
    /// Modèle le plus capable : le compte rendu s'écrit après le call, sans urgence.
    static let model = "opus"

    /// Consignes du compte rendu, avec les emplacements `{{prompt}}` et `{{playbook}}` du profil.
    private let instructions: String

    public init(instructions: String) {
        self.instructions = instructions
    }

    /// Titre, résumé et débrief du call. La transcription passe par stdin, jamais en argument.
    public func recap(of call: SavedCall) async throws(CallArchiveError) -> CallRecap {
        fatalError("TODO")
    }

    /// Consignes avec le prompt et le playbook du profil à leurs emplacements. Logique pure.
    static func systemPrompt(instructions: String, profile: SavedCall.Profile) -> String {
        fatalError("TODO")
    }

    /// Transcription envoyée à Claude, une réplique par ligne : « [04:12] Moi : … ». Logique pure.
    static func transcriptText(of call: SavedCall) -> String {
        fatalError("TODO")
    }

    /// Compte rendu lu dans la réponse JSON de Claude. Logique pure.
    static func recap(from response: String) throws(CallArchiveError) -> CallRecap {
        fatalError("TODO")
    }
}
