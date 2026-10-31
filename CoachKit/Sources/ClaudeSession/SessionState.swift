/// État de la session, affiché dans l'UI.
public enum SessionState: Equatable, Sendable {
    /// Aucun process `claude` lancé.
    case stopped
    /// Le process `claude` tourne et accepte des requêtes.
    case running
}
