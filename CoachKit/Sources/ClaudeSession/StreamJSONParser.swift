import Foundation

/// Décode une ligne de la sortie `stream-json` du CLI. Une ligne invalide est ignorée, jamais fatale.
struct StreamJSONParser {
    private let decoder = JSONDecoder()

    /// Événement porté par la ligne, ou `nil` si elle ne nous intéresse pas.
    /// Lève une erreur si la ligne n'est pas du JSON valide : l'appelant la journalise et passe à la suivante.
    func parse(_ line: String) throws -> StreamEvent? {
        let output = try decoder.decode(StreamOutputLine.self, from: Data(line.utf8))
        switch output.type {
        case "stream_event":
            // Les blocs de réflexion (`thinking_delta`) et les signatures sont ignorés : seul le texte s'affiche.
            guard let event = output.event, event.type == "content_block_delta",
                  let delta = event.delta, delta.type == "text_delta",
                  let text = delta.text
            else { return nil }
            return .textDelta(text)
        case "result":
            return output.isError == true ? .failed(message: output.result ?? "") : .completed
        default:
            return nil
        }
    }
}
