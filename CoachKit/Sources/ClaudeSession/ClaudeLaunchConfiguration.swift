import Foundation

/// Arguments, environnement et répertoire de travail du process `claude` (voir la section Sécurité du CLAUDE.md).
struct ClaudeLaunchConfiguration: Equatable, Sendable {
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
        workingDirectory: URL,
        parentEnvironment: [String: String]
    ) {
        var environment = parentEnvironment.filter { Self.inheritedVariables.contains($0.key) }
        environment["PATH"] = Self.path
        self.init(
            executableURL: executableURL,
            arguments: [
                "-p",
                "--input-format", "stream-json",
                "--output-format", "stream-json",
                "--verbose",
                "--include-partial-messages",
                "--model", options.model,
                "--tools", "",
                "--strict-mcp-config",
                "--setting-sources", "",
                "--no-session-persistence",
                "--system-prompt", options.systemPrompt,
            ],
            environment: environment,
            workingDirectory: workingDirectory
        )
    }
}
