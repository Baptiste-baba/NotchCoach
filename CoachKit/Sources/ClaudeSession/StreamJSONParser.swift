/// Décode une ligne de la sortie `stream-json` du CLI. Une ligne invalide est ignorée, jamais fatale.
struct StreamJSONParser {
    /// Événement porté par la ligne, ou `nil` si elle ne nous intéresse pas.
    /// Lève une erreur si la ligne n'est pas du JSON valide : l'appelant la journalise et passe à la suivante.
    func parse(_ line: String) throws -> StreamEvent? {
        fatalError("TODO")
    }
}
