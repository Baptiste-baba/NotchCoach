import Foundation

/// Calls enregistrés dans `~/Library/Application Support/NotchCoach/Calls/`, un fichier JSON par call, supprimés au
/// bout de 6 mois. Fait écrire le compte rendu de chaque call en arrière-plan.
public actor CallArchive {
    /// `~/Library/Application Support/NotchCoach/Calls/` : l'app n'est pas sandboxée.
    public static let standardDirectory = URL.applicationSupportDirectory.appending(components: "NotchCoach", "Calls")
    /// Durée de conservation d'un call.
    static let retention = DateComponents(month: 6)

    /// Un événement à chaque changement : call enregistré, compte rendu écrit ou en échec, call supprimé. Un seul
    /// consommateur, la fenêtre des calls.
    public nonisolated let updates: AsyncStream<Void>
    private let updatesContinuation: AsyncStream<Void>.Continuation
    private let directory: URL
    private let now: @Sendable () -> Date
    private let writeRecap: @Sendable (SavedCall) async throws -> CallRecap

    /// `writeRecap` écrit le compte rendu d'un call : `CallRecapGenerator` dans l'app, une fonction de test sinon.
    public init(
        directory: URL = CallArchive.standardDirectory,
        now: @escaping @Sendable () -> Date = { Date() },
        writeRecap: @escaping @Sendable (SavedCall) async throws -> CallRecap
    ) {
        (updates, updatesContinuation) = AsyncStream.makeStream()
        self.directory = directory
        self.now = now
        self.writeRecap = writeRecap
    }

    /// Au lancement de l'app : supprime les calls de plus de 6 mois, et passe en échec les comptes rendus restés en
    /// cours d'écriture à la fermeture précédente, pour qu'ils puissent être réécrits.
    public func start() {
        fatalError("TODO")
    }

    /// Calls enregistrés, du plus récent au plus ancien.
    public func calls() -> [SavedCall] {
        fatalError("TODO")
    }

    /// Enregistre un call terminé, puis fait écrire son compte rendu en arrière-plan. Supprime au passage les calls de
    /// plus de 6 mois.
    public func record(_ call: SavedCall) {
        fatalError("TODO")
    }

    /// Fait réécrire le compte rendu d'un call, après un échec.
    public func retryRecap(of id: SavedCall.ID) {
        fatalError("TODO")
    }

    /// Supprime un call, à la demande de l'utilisateur.
    public func delete(_ id: SavedCall.ID) throws(CallArchiveError) {
        fatalError("TODO")
    }

    /// Un call de plus de 6 mois, à supprimer. Logique pure.
    static func isExpired(_ call: SavedCall, now: Date, calendar: Calendar) -> Bool {
        fatalError("TODO")
    }
}
