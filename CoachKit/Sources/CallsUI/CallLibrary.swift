import CallArchive
import Observation

/// Calls enregistrés, tels que la fenêtre les affiche : relus à chaque changement de l'archive.
@MainActor
@Observable
public final class CallLibrary {
    /// Calls regroupés par période, du plus récent au plus ancien.
    public private(set) var periods: [CallPeriod] = []

    @ObservationIgnored private let archive: CallArchive

    public init(archive: CallArchive) {
        self.archive = archive
    }

    /// Lit les calls, puis les relit à chaque changement de l'archive, aussi longtemps que l'app tourne.
    public func start() {
        fatalError("TODO")
    }

    public func delete(_ call: SavedCall) {
        fatalError("TODO")
    }

    public func retryRecap(of call: SavedCall) {
        fatalError("TODO")
    }
}
