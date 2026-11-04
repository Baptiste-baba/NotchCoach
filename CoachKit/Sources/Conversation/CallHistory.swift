/// Historique d'un call, tel que la notch l'affiche : les suggestions de Claude et les échecs, du plus ancien au plus
/// récent. Logique pure.
struct CallHistory {
    /// Entrées, de la plus ancienne à la plus récente.
    private(set) var entries: [CallDisplay.Entry] = []

    /// Texte de la suggestion de `requestID`, complet jusqu'ici : ajoutée en bas la première fois, mise à jour ensuite.
    mutating func showSuggestion(_ text: String, requestID: Int) {
        fatalError("TODO")
    }

    /// Ajoute un échec en bas de l'historique.
    mutating func addFailure(_ text: String) {
        fatalError("TODO")
    }
}
