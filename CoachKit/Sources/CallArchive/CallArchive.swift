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
    /// Fichiers illisibles déjà journalisés : la liste est relue souvent, une fois suffit par lancement.
    private var reportedUnreadableFiles: Set<String> = []

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
            saveOrLog(call)
        }
        updatesContinuation.yield()
    }

    /// Calls enregistrés, du plus récent au plus ancien. Un fichier illisible est ignoré.
    public func calls() -> [SavedCall] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { load($0) }
            .sorted { $0.startDate > $1.startDate }
    }

    /// Enregistre un call terminé, puis fait écrire son compte rendu en arrière-plan. Supprime au passage les calls de
    /// plus de 6 mois. Un call qui n'a pas pu être enregistré est signalé : il serait perdu.
    public func record(_ call: SavedCall) throws(CallArchiveError) {
        deleteExpiredCalls()
        var call = call
        call.recapStatus = .writing
        try save(call)
        updatesContinuation.yield()
        startRecap(of: call)
    }

    /// Fait réécrire le compte rendu d'un call, après un échec.
    public func retryRecap(of id: SavedCall.ID) {
        guard !recapsInProgress.contains(id), var call = load(fileURL(of: id)) else { return }
        call.recapStatus = .writing
        guard saveOrLog(call) else { return }
        updatesContinuation.yield()
        startRecap(of: call)
    }

    /// Supprime un call, à la demande de l'utilisateur. Un call déjà supprimé, par l'expiration par exemple, n'est pas
    /// un échec.
    public func delete(_ id: SavedCall.ID) throws(CallArchiveError) {
        let url = fileURL(of: id)
        defer { updatesContinuation.yield() }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw .deleteFailed(reason: error.localizedDescription)
        }
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
            logger.error("Compte rendu non écrit pour \(call.id, privacy: .public) : \(error.localizedDescription, privacy: .public)")
            status = .failed(reason: error.localizedDescription)
        }
        recapsInProgress.remove(call.id)
        // Relu avant d'écrire : le call a pu être supprimé pendant que Claude écrivait.
        guard var saved = load(fileURL(of: call.id)) else { return }
        saved.recapStatus = status
        // Non enregistré, il reste « en cours d'écriture » : au prochain lancement, il pourra être réécrit.
        saveOrLog(saved)
        updatesContinuation.yield()
    }

    // MARK: Fichiers

    private func deleteExpiredCalls() {
        let now = now()
        for call in calls() where Self.isExpired(call, now: now, calendar: .current) {
            do {
                try FileManager.default.removeItem(at: fileURL(of: call.id))
            } catch {
                logger.error("Call expiré non supprimé, \(call.id, privacy: .public) : \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func fileURL(of id: SavedCall.ID) -> URL {
        directory.appending(component: "\(id.uuidString).json")
    }

    private func load(_ url: URL) -> SavedCall? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try Self.decoder.decode(SavedCall.self, from: data)
        } catch {
            if reportedUnreadableFiles.insert(url.lastPathComponent).inserted {
                logger.error("Call illisible, ignoré : \(url.lastPathComponent, privacy: .public)")
            }
            return nil
        }
    }

    private func save(_ call: SavedCall) throws(CallArchiveError) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Self.encoder.encode(call).write(to: fileURL(of: call.id), options: .atomic)
        } catch {
            throw .saveFailed(reason: error.localizedDescription)
        }
    }

    /// Enregistre en arrière-plan, sans personne à qui montrer l'échec : il est journalisé. Renvoie `true` si le call
    /// est enregistré.
    @discardableResult
    private func saveOrLog(_ call: SavedCall) -> Bool {
        do {
            try save(call)
            return true
        } catch {
            logger.error("Call non enregistré, \(call.id, privacy: .public) : \(error.localizedDescription, privacy: .public)")
            return false
        }
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
