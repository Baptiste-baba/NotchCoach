import Foundation

/// Échecs de la source audio, avec un message affichable.
public enum AudioCaptureError: Error, Equatable, Sendable, LocalizedError {
    /// Le fichier à rejouer n'existe pas.
    case replayFileNotFound(path: String)
    /// Le fichier à rejouer existe mais n'est pas un fichier audio lisible.
    case replayFileUnreadable(path: String, reason: String)
    /// Le fichier à rejouer n'a pas deux canaux (gauche = moi, droite = prospect).
    case replayFileNotStereo(channelCount: Int)
    /// Le format du fichier ne peut pas être converti en 16 kHz.
    case unsupportedReplayFormat

    public var errorDescription: String? {
        switch self {
        case .replayFileNotFound(let path):
            "Fichier de replay introuvable : \(path)"
        case .replayFileUnreadable(let path, let reason):
            "Impossible de lire \(path) : \(reason)"
        case .replayFileNotStereo(let channelCount):
            "Le fichier de replay doit être en stéréo (gauche = moi, droite = prospect), il a \(channelCount) canal(aux)."
        case .unsupportedReplayFormat:
            "Le format du fichier de replay n'est pas pris en charge."
        }
    }
}
