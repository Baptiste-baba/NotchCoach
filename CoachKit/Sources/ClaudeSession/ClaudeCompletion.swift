import Foundation

/// Requête unique au CLI `claude` : un process lancé pour une seule réponse, qui se termine ensuite. Même isolation que
/// la session des calls (voir la section Sécurité du CLAUDE.md). Sert quand la latence ne compte pas, comme pour écrire
/// le prompt d'un nouveau profil.
public struct ClaudeCompletion: Sendable {
    private let options: ClaudeSessionOptions

    public init(options: ClaudeSessionOptions) {
        self.options = options
    }

    /// Envoie `input` sur stdin et renvoie la réponse complète de Claude. L'annulation de la tâche arrête le process et
    /// lève `CancellationError`. Les autres échecs lèvent une `ClaudeSessionError`.
    public func complete(_ input: String) async throws -> String {
        let configuration = ClaudeLaunchConfiguration(
            executableURL: try await ClaudeBinaryLocator().locate(override: options.binaryPathOverride),
            options: options,
            mode: .singleResponse,
            workingDirectory: try ClaudeLaunchConfiguration.makeWorkingDirectory(),
            parentEnvironment: ClaudeLaunchConfiguration.appEnvironment
        )
        let process = try ClaudeProcess(configuration: configuration)
        let output = await withTaskCancellationHandler {
            // La requête passe par stdin, jamais en argument : elle serait visible avec `ps`. Un process mort avant de
            // la lire l'est pour une raison que sa sortie, lue ensuite, explique mieux que l'échec de l'écriture.
            try? process.write(line: input)
            process.closeInput()
            var output = ""
            for await line in process.outputLines {
                output += line + "\n"
            }
            return output
        } onCancel: {
            process.terminate()
        }
        // Process arrêté par l'annulation : sa sortie, incomplète, n'est pas une erreur à signaler.
        try Task.checkCancellation()
        return try Self.response(fromOutput: output)
    }

    /// Réponse de Claude lue dans la sortie du CLI : un objet JSON `result`. Logique pure.
    static func response(fromOutput output: String) throws(ClaudeSessionError) -> String {
        guard let result = try? JSONDecoder().decode(StreamOutputLine.self, from: Data(output.utf8)),
              result.type == "result",
              let text = result.result
        else {
            throw .invalidResponse
        }
        // Seul `is_error` est fiable : `subtype` vaut `success` même en cas d'échec.
        guard result.isError != true else {
            throw .responseFailed(message: text)
        }
        return text
    }
}
