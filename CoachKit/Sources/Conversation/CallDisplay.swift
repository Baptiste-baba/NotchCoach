/// Ce que la notch doit afficher pendant un call : l'historique du call et le message d'état du moment. Vide, la notch
/// est repliée. Publié par `CallPipeline` pendant le démarrage du call, puis par `ConversationCoordinator`.
public struct CallDisplay: Equatable, Sendable {
    /// Une entrée de l'historique du call.
    public struct Entry: Equatable, Sendable, Identifiable {
        public enum Kind: Equatable, Sendable {
            /// Suggestion de Claude, complète ou encore en train de s'écrire.
            case suggestion
            /// Échec, affiché en rouge : Claude n'a pas pu répondre ou est indisponible, capture coupée, call sans
            /// playbook, démarrage impossible.
            case failure
        }

        /// Unique dans le call et stable pendant que l'entrée s'écrit : la notch suit chaque entrée d'un affichage
        /// à l'autre.
        public let id: Int
        public var kind: Kind
        public var text: String

        public init(id: Int, kind: Kind, text: String) {
            self.id = id
            self.kind = kind
            self.text = text
        }
    }

    /// Historique du call, du plus ancien au plus récent.
    public var entries: [Entry]
    /// Message d'état passager, sous l'historique : démarrage du call, redémarrage de Claude. `nil` s'il n'y en a pas.
    public var notice: String?

    public init(entries: [Entry] = [], notice: String? = nil) {
        self.entries = entries
        self.notice = notice
    }
}
