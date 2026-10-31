import Foundation

/// Trouve le binaire `claude` : chemin forcé dans les réglages, sinon résolu via le shell de connexion
/// (une app graphique n'hérite pas du PATH du terminal), puis mis en cache.
struct ClaudeBinaryLocator {
    func locate(override: URL?) async throws -> URL {
        fatalError("TODO")
    }
}
