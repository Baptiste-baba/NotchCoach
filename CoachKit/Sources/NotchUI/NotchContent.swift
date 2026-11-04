/// Ce que le panel affiche.
public enum NotchContent: Equatable, Sendable {
    /// Rien : le panel reste replié sur la notch.
    case empty
    /// Texte affiché sous la notch, panel déplié.
    case text(String)
    /// Message d'erreur affiché sous la notch, en rouge, panel déplié.
    case error(String)
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
