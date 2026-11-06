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
    /// Calls dont le compte rendu est en train de s'écrire, dans ce lancement de l'app.
    private var recapsInProgress: Set<SavedCall.ID> = []

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
        deleteExpiredCalls()
        for var call in calls() where call.recapStatus == .writing && !recapsInProgress.contains(call.id) {
            call.recapStatus = .failed(reason: "L'écriture a été interrompue par la fermeture de l'app.")
            save(call)
        }
        updatesContinuation.yield()
    }

    /// Calls enregistrés, du plus récent au plus ancien.
    public func calls() -> [SavedCall] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { load($0) }
            .sorted { $0.startDate > $1.startDate }
    }

    /// Enregistre un call terminé, puis fait écrire son compte rendu en arrière-plan. Supprime au passage les calls de
    /// plus de 6 mois.
    public func record(_ call: SavedCall) {
        deleteExpiredCalls()
        var call = call
        call.recapStatus = .writing
        save(call)
        updatesContinuation.yield()
        startRecap(of: call)
    }

    /// Fait réécrire le compte rendu d'un call, après un échec.
    public func retryRecap(of id: SavedCall.ID) {
        guard !recapsInProgress.contains(id), var call = load(fileURL(of: id)) else { return }
        call.recapStatus = .writing
        save(call)
        updatesContinuation.yield()
        startRecap(of: call)
    }

    /// Supprime un call, à la demande de l'utilisateur.
    public func delete(_ id: SavedCall.ID) throws(CallArchiveError) {
        try? FileManager.default.removeItem(at: fileURL(of: id))
        updatesContinuation.yield()
    }

    /// Un call de plus de 6 mois, à supprimer. Logique pure.
    static func isExpired(_ call: SavedCall, now: Date, calendar: Calendar) -> Bool {
        guard let limit = calendar.date(byAdding: retention, to: call.startDate) else { return false }
        return limit <= now
    }

    // MARK: Compte rendu

    private func startRecap(of call: SavedCall) {
        recapsInProgress.insert(call.id)
        Task { await writeAndSaveRecap(of: call) }
    }

    private func writeAndSaveRecap(of call: SavedCall) async {
        let status: SavedCall.RecapStatus
        do {
            status = .written(recap: try await writeRecap(call))
        } catch {
            status = .failed(reason: error.localizedDescription)
        }
        recapsInProgress.remove(call.id)
        // Relu avant d'écrire : le call a pu être supprimé pendant que Claude écrivait.
        guard var saved = load(fileURL(of: call.id)) else { return }
        saved.recapStatus = status
        save(saved)
        updatesContinuation.yield()
    }

    // MARK: Fichiers

    private func deleteExpiredCalls() {
        let now = now()
        for call in calls() where Self.isExpired(call, now: now, calendar: .current) {
            try? FileManager.default.removeItem(at: fileURL(of: call.id))
        }
    }

    private func fileURL(of id: SavedCall.ID) -> URL {
        directory.appending(component: "\(id.uuidString).json")
    }

    private func load(_ url: URL) -> SavedCall? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(SavedCall.self, from: data)
    }

    private func save(_ call: SavedCall) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? Self.encoder.encode(call) else { return }
        try? data.write(to: fileURL(of: call.id), options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
