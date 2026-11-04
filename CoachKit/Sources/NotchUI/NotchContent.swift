/// Ce que le panel affiche : l'historique du call et le message d'état du moment. Vide, le panel reste replié sur la
/// notch ; sinon, il se déplie dessous.
public struct NotchContent: Equatable, Sendable {
    /// Rien : le panel reste replié.
    public static let empty = NotchContent()

    /// Historique, du plus ancien au plus récent.
    public var lines: [Line]
    /// Message d'état passager, sous l'historique, ou `nil`.
    public var notice: String?

    public init(lines: [Line] = [], notice: String? = nil) {
        self.lines = lines
        self.notice = notice
    }

    /// Rien à afficher : le panel reste replié.
    public var isEmpty: Bool {
        lines.isEmpty && notice == nil
    }
}

extension NotchContent {
    /// Une ligne de l'historique affiché sous la notch.
    public struct Line: Equatable, Sendable, Identifiable {
        /// Stable pendant que la ligne s'écrit : la notch suit chaque ligne d'un affichage à l'autre.
        public let id: Int
        public var text: String
        /// Affichée en rouge.
        public var isError: Bool

        public init(id: Int, text: String, isError: Bool = false) {
            self.id = id
            self.text = text
            self.isError = isError
        }
    }
}
