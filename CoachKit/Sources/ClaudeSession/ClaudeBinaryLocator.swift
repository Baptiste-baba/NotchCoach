import Foundation

/// Trouve le binaire `claude` : chemin forcé dans les réglages, sinon résolu via le shell de connexion
/// (une app graphique n'hérite pas du PATH du terminal), puis mis en cache.
struct ClaudeBinaryLocator {
    private static let cacheKey = "ClaudeBinaryPath"

    func locate(override: URL?) async throws -> URL {
        let fileManager = FileManager.default
        if let override {
            guard fileManager.isExecutableFile(atPath: override.path) else {
                throw ClaudeSessionError.binaryNotExecutable(path: override.path)
            }
            return override
        }
        if let cached = UserDefaults.standard.string(forKey: Self.cacheKey) {
            if fileManager.isExecutableFile(atPath: cached) {
                return URL(filePath: cached)
            }
            // CLI désinstallé ou déplacé depuis la mise en cache : on cherche à nouveau.
            UserDefaults.standard.removeObject(forKey: Self.cacheKey)
        }
        let path = try await resolveWithLoginShell()
        // Sortie vide si rien n'est trouvé, ou texte comme `alias claude=…` si c'est un alias du shell.
        guard path.hasPrefix("/") else {
            throw ClaudeSessionError.binaryNotFound
        }
        guard fileManager.isExecutableFile(atPath: path) else {
            throw ClaudeSessionError.binaryNotExecutable(path: path)
        }
        // On garde le chemin renvoyé (lien `~/.local/bin/claude`), pas sa cible versionnée.
        UserDefaults.standard.set(path, forKey: Self.cacheKey)
        return URL(filePath: path)
    }

    private func resolveWithLoginShell() async throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/zsh")
        process.arguments = ["-lc", "command -v claude"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let handle = output.fileHandleForReading

        let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, any Error>) in
            process.terminationHandler = { _ in
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ClaudeSessionError.binaryNotFound)
            }
        }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
