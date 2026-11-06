import CallArchive
import Foundation
import Observation

/// Calls enregistrés, tels que la fenêtre les affiche : relus à chaque changement de l'archive.
@MainActor
@Observable
public final class CallLibrary {
    /// Calls regroupés par période, du plus récent au plus ancien.
    public private(set) var periods: [CallPeriod] = []
    /// Échec d'une suppression, à montrer dans la fenêtre ; `nil` une fois l'alerte fermée.
    public var deletionError: String?

    @ObservationIgnored private let archive: CallArchive
    @ObservationIgnored private var isStarted = false

    public init(archive: CallArchive) {
        self.archive = archive
    }

    /// Lit les calls, puis les relit à chaque changement de l'archive, aussi longtemps que l'app tourne.
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        Task {
            await reload()
            for await _ in archive.updates {
                await reload()
            }
        }
    }

    /// Relit les calls : les périodes (« Aujourd'hui »…) changent avec les jours, même sans nouveau call.
    public func refresh() {
        Task { await reload() }
    }

    public func call(withID id: SavedCall.ID?) -> SavedCall? {
        periods.lazy.flatMap(\.calls).first { $0.id == id }
    }

    public func delete(_ call: SavedCall) {
        Task {
            do {
                try await archive.delete(call.id)
            } catch {
                deletionError = error.localizedDescription
            }
        }
    }

    public func retryRecap(of call: SavedCall) {
        Task { await archive.retryRecap(of: call.id) }
    }

    private func reload() async {
        periods = CallPeriod.group(await archive.calls(), now: Date())
    }
}
