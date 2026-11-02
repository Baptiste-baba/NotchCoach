/// Ce que le panel affiche.
public enum NotchContent: Equatable, Sendable {
    /// Rien : le panel reste replié sur la notch.
    case empty
    /// Texte affiché sous la notch, panel déplié.
    case text(String)
    /// Message d'erreur affiché sous la notch, en rouge, panel déplié.
    case error(String)
}
