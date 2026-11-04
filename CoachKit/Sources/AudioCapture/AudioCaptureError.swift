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
    /// L'accès au micro est refusé dans Réglages Système.
    case microphoneDenied
    /// Le micro ne peut pas être capté, au démarrage ou après un changement d'appareil.
    case microphoneUnavailable(reason: String)
    /// L'enregistrement de l'écran, par lequel passe l'audio du Mac, n'est pas autorisé.
    case screenRecordingDenied
    /// L'audio du Mac ne peut pas être capté, au démarrage ou après une coupure.
    case systemAudioUnavailable(reason: String)

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
        case .microphoneDenied:
            "NotchCoach n'a pas accès au micro. Autorisez-le dans Réglages Système > Confidentialité et sécurité > Micro."
        case .microphoneUnavailable(let reason):
            "Micro indisponible : \(reason)"
        case .screenRecordingDenied:
            "NotchCoach n'a pas accès à l'audio du Mac. Autorisez l'enregistrement de l'écran dans Réglages Système > Confidentialité et sécurité, puis relancez NotchCoach."
        case .systemAudioUnavailable(let reason):
            "Audio du Mac indisponible : \(reason)"
        }
    }
}
