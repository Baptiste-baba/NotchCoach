import Foundation

/// Requête unique au CLI `claude` : un process lancé pour une seule réponse, qui se termine ensuite. Même isolation que
/// la session des calls (voir la section Sécurité du CLAUDE.md). Sert quand la latence ne compte pas, comme pour écrire
/// le prompt d'un nouveau profil.
public struct ClaudeCompletion: Sendable {
    private let options: ClaudeSessionOptions

    public init(options: ClaudeSessionOptions) {
        self.options = options
    }

    /// Envoie `input` sur stdin et renvoie la réponse complète de Claude. L'annulation de la tâche arrête le process.
    public func complete(_ input: String) async throws -> String {
        let configuration = ClaudeLaunchConfiguration(
            executableURL: try await ClaudeBinaryLocator().locate(override: options.binaryPathOverride),
            options: options,
            mode: .singleResponse,
            workingDirectory: try ClaudeLaunchConfiguration.makeWorkingDirectory(),
            parentEnvironment: ClaudeLaunchConfiguration.appEnvironment
        )
        let process = try ClaudeProcess(configuration: configuration)
        let output = try await withTaskCancellationHandler {
            // La requête passe par stdin, jamais en argument : elle serait visible avec `ps`.
            try process.write(line: input)
            process.closeInput()
            var output = ""
            for await line in process.outputLines {
                output += line + "\n"
            }
            return output
        } onCancel: {
            process.terminate()
        }
        let result = try JSONDecoder().decode(StreamOutputLine.self, from: Data(output.utf8))
        guard result.type == "result", result.isError == false, let text = result.result else {
            fatalError("TODO couche Erreurs")
        }
        return text
    }
}
