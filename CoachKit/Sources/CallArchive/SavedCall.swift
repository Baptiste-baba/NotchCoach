import Foundation

/// Call enregistré : sa date, son profil, sa durée, sa transcription et son compte rendu. Gardé 6 mois.
public struct SavedCall: Codable, Equatable, Identifiable, Sendable {
    /// Qui parle. Le micro est l'utilisateur, l'audio du Mac son interlocuteur.
    public enum Speaker: String, Codable, Sendable {
        case me
        case interlocutor
    }

    /// Réplique de la transcription.
    public struct Line: Codable, Equatable, Sendable {
        public var speaker: Speaker
        /// Début de la réplique, en secondes depuis le début du call.
        public var start: TimeInterval
        public var text: String

        public init(speaker: Speaker, start: TimeInterval, text: String) {
            self.speaker = speaker
            self.start = start
            self.text = text
        }
    }

    /// Profil utilisé pendant le call, tel qu'il était : le compte rendu peut être réécrit plus tard, même si le
    /// profil a changé ou a été supprimé depuis.
    public struct Profile: Codable, Equatable, Sendable {
        public var name: String
        public var prompt: String
        public var playbook: String

        public init(name: String, prompt: String, playbook: String) {
            self.name = name
            self.prompt = prompt
            self.playbook = playbook
        }
    }

    /// Où en est le compte rendu.
    public enum RecapStatus: Codable, Equatable, Sendable {
        /// En cours d'écriture. Enregistré tel quel si l'app se ferme avant la fin : il est alors à réécrire.
        case writing
        case written(recap: CallRecap)
        /// Claude n'a pas pu l'écrire ; la transcription reste disponible.
        case failed(reason: String)
    }

    public var id: UUID
    public var startDate: Date
    public var duration: TimeInterval
    public var profile: Profile
    public var transcript: [Line]
    public var recapStatus: RecapStatus

    public init(
        id: UUID = UUID(),
        startDate: Date,
        duration: TimeInterval,
        profile: Profile,
        transcript: [Line],
        recapStatus: RecapStatus = .writing
    ) {
        self.id = id
        self.startDate = startDate
        self.duration = duration
        self.profile = profile
        self.transcript = transcript
        self.recapStatus = recapStatus
    }
}

extension SavedCall {
    /// Réplique citée à `moment` (le début d'une réplique, à la seconde près, comme dans « 04:12 ») : la dernière qui
    /// commence au plus tard à cette seconde. `nil` s'il n'y en a aucune. Logique pure.
    public func lineIndex(at moment: TimeInterval) -> Int? {
        transcript.lastIndex { $0.start.rounded(.down) <= moment }
    }
}
