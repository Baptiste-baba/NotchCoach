/// Ce que le coordinateur affiche, une entrée à la fois. Traduit en `CallDisplay` en attendant l'historique du call.
enum CoachDisplay: Equatable, Sendable {
    /// Notch repliée.
    case hidden
    /// Suggestion de Claude, complète ou encore en train de s'écrire.
    case suggestion(String)
    /// Message d'état : redémarrage de Claude.
    case notice(String)
    /// Échec, affiché en rouge : Claude n'a pas pu répondre ou il est indisponible.
    case error(String)
}

extension CallDisplay {
    /// Une seule entrée, ou seulement le message passager.
    init(_ display: CoachDisplay) {
        switch display {
        case .hidden:
            self.init()
        case .suggestion(let text):
            self.init(entries: [Entry(id: 0, kind: .suggestion, text: text)])
        case .notice(let text):
            self.init(notice: text)
        case .error(let text):
            self.init(entries: [Entry(id: 0, kind: .failure, text: text)])
        }
    }
}
