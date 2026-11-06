import Foundation

/// Compte rendu d'un call écrit par Claude : un titre court, le résumé et le débrief pour progresser.
public struct CallRecap: Codable, Equatable, Sendable {
    /// Ce qui s'est dit.
    public struct Summary: Codable, Equatable, Sendable {
        /// De quoi on a parlé, en un paragraphe.
        public var overview: String
        /// Ce qui a été dit d'important, et les décisions prises.
        public var keyPoints: [String]
        /// Ce qui doit se passer ensuite.
        public var nextSteps: [String]

        public init(overview: String, keyPoints: [String], nextSteps: [String]) {
            self.overview = overview
            self.keyPoints = keyPoints
            self.nextSteps = nextSteps
        }
    }

    /// Point à travailler : ce qui n'a pas marché, et comment mieux faire.
    public struct Improvement: Codable, Equatable, Sendable {
        /// Ce qui n'a pas marché, en une phrase.
        public var issue: String
        /// Moment de la transcription concerné, en secondes depuis le début du call ; `nil` pour un oubli, qui n'a
        /// pas de moment précis.
        public var moment: TimeInterval?
        /// Phrase de l'utilisateur à ce moment ; `nil` pour un oubli.
        public var quote: String?
        /// Ce que l'utilisateur aurait pu dire à la place.
        public var betterPhrasing: String

        public init(issue: String, moment: TimeInterval?, quote: String?, betterPhrasing: String) {
            self.issue = issue
            self.moment = moment
            self.quote = quote
            self.betterPhrasing = betterPhrasing
        }
    }

    /// Ce qui a marché et ce qui est à travailler.
    public struct Debrief: Codable, Equatable, Sendable {
        public var strengths: [String]
        public var improvements: [Improvement]

        public init(strengths: [String], improvements: [Improvement]) {
            self.strengths = strengths
            self.improvements = improvements
        }
    }

    /// Quelques mots, affichés dans la liste des calls (« Objection prix, Mme Martin »).
    public var title: String
    public var summary: Summary
    public var debrief: Debrief

    public init(title: String, summary: Summary, debrief: Debrief) {
        self.title = title
        self.summary = summary
        self.debrief = debrief
    }
}
