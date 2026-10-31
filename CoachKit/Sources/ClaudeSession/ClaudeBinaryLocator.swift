import Foundation

/// Trouve le binaire `claude` : chemin forcé dans les réglages, sinon résolu via le shell de connexion
/// (une app graphique n'hérite pas du PATH du terminal), puis mis en cache.
struct ClaudeBinaryLocator {
    private static let cacheKey = "ClaudeBinaryPath"

    func locate(override: URL?) async throws -> URL {
        if let override {
            return override
        }
        if let cached = UserDefaults.standard.string(forKey: Self.cacheKey) {
            return URL(filePath: cached)
        }
        // On garde le chemin renvoyé (lien `~/.local/bin/claude`), pas sa cible versionnée.
        let path = try await resolveWithLoginShell()
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
                continuation.resume(throwing: error)
            }
        }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
