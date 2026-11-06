import Foundation

/// Arguments, environnement et répertoire de travail du process `claude` (voir la section Sécurité du CLAUDE.md).
struct ClaudeLaunchConfiguration: Equatable, Sendable {
    /// Façon dont l'app échange avec le process.
    enum Mode: Equatable, Sendable {
        /// Session des calls : messages et réponses en `stream-json`, texte reçu token par token.
        case streaming
        /// Une seule réponse : la requête sur stdin, la réponse en un objet JSON, puis le process se termine.
        case singleResponse
    }

    var executableURL: URL
    var arguments: [String]
    /// Environnement complet du process, construit explicitement : jamais hérité de l'app.
    var environment: [String: String]
    /// Répertoire de travail dédié et vide.
    var workingDirectory: URL
}

extension ClaudeLaunchConfiguration {
    /// Variables reprises de l'app. `USER` est indispensable : sans lui, le CLI ne trouve pas ses identifiants
    /// dans le trousseau. Liste fermée : `ANTHROPIC_API_KEY` ne passe jamais.
    private static let inheritedVariables: Set<String> = ["HOME", "USER", "LANG"]
    private static let path = "/usr/bin:/bin:/usr/sbin:/sbin"

    /// Construit la configuration retenue. Seules les variables nécessaires sont reprises de `parentEnvironment`.
    init(
        executableURL: URL,
        options: ClaudeSessionOptions,
        mode: Mode = .streaming,
        workingDirectory: URL,
        parentEnvironment: [String: String]
    ) {
        var environment = parentEnvironment.filter { Self.inheritedVariables.contains($0.key) }
        environment["PATH"] = Self.path
        let exchange = switch mode {
        case .streaming:
            [
                "--input-format", "stream-json",
                "--output-format", "stream-json",
                "--verbose",
                "--include-partial-messages",
            ]
        case .singleResponse:
            ["--output-format", "json"]
        }
        // Isolation, identique dans les deux modes : aucun outil, aucun serveur MCP, aucun réglage de l'utilisateur,
        // rien d'écrit dans `~/.claude/projects/`, et le prompt par défaut de Claude Code remplacé.
        let isolation = [
            "--model", options.model,
            "--tools", "",
            "--strict-mcp-config",
            "--setting-sources", "",
            "--no-session-persistence",
            "--system-prompt", options.systemPrompt,
        ]
        self.init(
            executableURL: executableURL,
            arguments: ["-p"] + exchange + isolation,
            environment: environment,
            workingDirectory: workingDirectory
        )
    }

    /// Environnement de l'app, complété de `USER` et `HOME` s'ils manquent : une app lancée hors du terminal peut ne
    /// pas les avoir, et le CLI en a besoin.
    static var appEnvironment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["USER"] = environment["USER"] ?? NSUserName()
        environment["HOME"] = environment["HOME"] ?? NSHomeDirectory()
        return environment
    }

    /// Répertoire de travail dédié et vide du process, créé s'il n'existe pas.
    static func makeWorkingDirectory() throws -> URL {
        let url = URL.applicationSupportDirectory
            .appending(path: "NotchCoach/ClaudeWorkingDirectory", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
