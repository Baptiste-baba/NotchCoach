/// Groupe de la liste des calls : « Aujourd'hui », « Cette semaine », puis un groupe par mois.
public struct CallPeriod: Equatable, Identifiable, Sendable {
    /// Nom affiché au-dessus du groupe.
    public var title: String
    /// Calls de la période, du plus récent au plus ancien.
    public var calls: [SavedCall]

    public init(title: String, calls: [SavedCall]) {
        self.title = title
        self.calls = calls
    }

    public var id: String { title }
}
