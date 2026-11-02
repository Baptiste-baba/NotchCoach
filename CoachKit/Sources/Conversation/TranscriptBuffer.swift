import Transcription

/// Accumule les segments du call et fournit, à chaque déclenchement, uniquement ceux qui n'ont pas encore
/// été envoyés à Claude, formatés pour le prompt. Logique pure.
public struct TranscriptBuffer {
    public init() {}

    /// Ajoute un segment de l'un ou l'autre canal, final ou non.
    public mutating func append(_ segment: TranscriptSegment) {
        fatalError("TODO")
    }

    /// Texte des segments pas encore envoyés, dans l'ordre chronologique et formaté pour le prompt, puis les marque
    /// comme envoyés. `nil` s'il n'y a rien de nouveau.
    public mutating func takeUnsent() -> String? {
        fatalError("TODO")
    }

    /// Après un redémarrage du process `claude`, dont la conversation repart vide : le prochain `takeUnsent()`
    /// renvoie toute la transcription du call.
    public mutating func markAllUnsent() {
        fatalError("TODO")
    }
}
