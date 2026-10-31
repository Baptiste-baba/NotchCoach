// Format `stream-json` du CLI, relevé sur Claude Code 2.1.310.

/// Message écrit sur stdin : une ligne JSON par message utilisateur.
struct StreamInputMessage: Encodable, Equatable {
    struct Message: Encodable, Equatable {
        var role = "user"
        var content: String
    }

    var type = "user"
    var message: Message
}

/// Demande d'interruption écrite sur stdin : arrête la réponse en cours, qui se termine alors par une ligne
/// `result` avec `is_error: true` (`terminal_reason: aborted_streaming`). Sans réponse en cours, elle n'a aucun
/// effet et ne produit pas de ligne `result`. Protocole des SDK Claude, absent de `claude --help`.
struct StreamInterruptRequest: Encodable, Equatable {
    struct Request: Encodable, Equatable {
        var subtype = "interrupt"
    }

    var type = "control_request"
    var requestID: String
    var request = Request()

    enum CodingKeys: String, CodingKey {
        case type, request
        case requestID = "request_id"
    }
}

/// Ligne de sortie du CLI, réduite aux champs utiles. Selon `type`, la plupart sont absents.
struct StreamOutputLine: Decodable {
    struct Event: Decodable {
        struct Delta: Decodable {
            /// Absent du `delta` d'un `message_delta`, qui porte `stop_reason` à la place.
            let type: String?
            let text: String?
        }

        let type: String
        let delta: Delta?
    }

    let type: String
    let event: Event?
    let isError: Bool?
    let result: String?

    enum CodingKeys: String, CodingKey {
        case type, event, result
        case isError = "is_error"
    }
}

/// Événement utile extrait d'une ligne de sortie. Les autres lignes (`system`, `assistant`,
/// `rate_limit_event`, autres `stream_event`…) sont ignorées.
enum StreamEvent: Equatable, Sendable {
    /// Morceau de texte de la réponse en cours : `stream_event` > `content_block_delta` > `text_delta`.
    case textDelta(String)
    /// Ligne `result` avec `is_error: false`.
    case completed
    /// Ligne `result` avec `is_error: true` ; le CLI met le message dans `result`.
    /// `subtype` vaut alors quand même `success` : seul `is_error` est fiable.
    case failed(message: String)
}
