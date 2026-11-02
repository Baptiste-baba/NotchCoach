import AudioCapture
import Transcription

/// Accumule les segments du call et fournit, à chaque déclenchement, uniquement ceux qui n'ont pas encore
/// été envoyés à Claude, formatés pour le prompt. Logique pure.
public struct TranscriptBuffer {
    private struct Entry {
        let segment: TranscriptSegment
        var isSent = false
    }

    /// Segments dans l'ordre chronologique de leur début.
    private var entries: [Entry] = []

    public init() {}

    /// Ajoute un segment de l'un ou l'autre canal, final ou non. Un segment sans texte (celui qui clôt une prise
    /// de parole coupée, par exemple) n'apporte rien au prompt et n'est pas gardé.
    public mutating func append(_ segment: TranscriptSegment) {
        guard !segment.text.allSatisfy(\.isWhitespace) else { return }
        // Les deux canaux sont transcrits chacun de leur côté : un segment peut arriver après un segment plus récent
        // de l'autre canal. Il est rangé selon son début, en général à la fin.
        let index = entries.lastIndex { $0.segment.start <= segment.start }.map { $0 + 1 } ?? 0
        entries.insert(Entry(segment: segment), at: index)
    }

    /// Texte des segments pas encore envoyés, dans l'ordre chronologique et formaté pour le prompt, puis les marque
    /// comme envoyés. `nil` s'il n'y a rien de nouveau.
    public mutating func takeUnsent() -> String? {
        let unsent = entries.indices.filter { !entries[$0].isSent }
        guard !unsent.isEmpty else { return nil }
        for index in unsent {
            entries[index].isSent = true
        }
        return unsent.map { Self.line(for: entries[$0].segment) }.joined(separator: "\n")
    }

    /// Après un redémarrage du process `claude`, dont la conversation repart vide : le prochain `takeUnsent()`
    /// renvoie toute la transcription du call.
    public mutating func markAllUnsent() {
        for index in entries.indices {
            entries[index].isSent = false
        }
    }

    // Étiquettes provisoires : elles rejoindront les fichiers de prompt avec le playbook à l'étape 6.
    private static func line(for segment: TranscriptSegment) -> String {
        let name = switch segment.speaker {
        case .me: "Moi"
        case .prospect: "Prospect"
        }
        // Une réplique tient sur une ligne : un retour à la ligne dans le texte ne peut pas fabriquer une fausse
        // ligne « Moi : ».
        let text = segment.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return "\(name) : \(text)"
    }
}
