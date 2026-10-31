/// État de la session, affiché dans l'UI.
public enum SessionState: Equatable, Sendable {
    /// Aucun process `claude` lancé.
    case stopped
    /// Le process `claude` tourne et accepte des requêtes.
    case running
    /// Le process est mort : nouvelle tentative de lancement en attente. Le nouveau process repart
    /// d'une conversation vide.
    case restarting(attempt: Int)
    /// Toutes les tentatives de redémarrage ont échoué ; `start()` permet de réessayer.
    case failed(message: String)
}
