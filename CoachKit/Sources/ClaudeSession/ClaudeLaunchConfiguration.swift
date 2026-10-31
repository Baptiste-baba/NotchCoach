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
    /// Construit la configuration retenue. Seules les variables nécessaires sont reprises de `parentEnvironment`.
    init(
        executableURL: URL,
        options: ClaudeSessionOptions,
        workingDirectory: URL,
        parentEnvironment: [String: String]
    ) {
        fatalError("TODO")
    }
}
