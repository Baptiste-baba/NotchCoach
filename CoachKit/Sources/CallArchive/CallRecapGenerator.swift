import ClaudeSession
import Foundation
import Prompting

/// Fait écrire par Claude le compte rendu d'un call, à partir de sa transcription et du profil utilisé.
public struct CallRecapGenerator: Sendable {
    /// Modèle le plus capable : le compte rendu s'écrit après le call, sans urgence.
    static let model = "opus"

    /// Consignes du compte rendu, avec les emplacements `{{prompt}}` et `{{playbook}}` du profil.
    private let instructions: String

    public init(instructions: String) {
        self.instructions = instructions
    }

    /// Titre, résumé et débrief du call. La transcription passe par stdin, jamais en argument.
    public func recap(of call: SavedCall) async throws(CallArchiveError) -> CallRecap {
        let systemPrompt = Self.systemPrompt(instructions: instructions, profile: call.profile)
        let completion = ClaudeCompletion(options: ClaudeSessionOptions(model: Self.model, systemPrompt: systemPrompt))
        let response: String
        do {
            response = try await completion.complete(Self.transcriptText(of: call))
        } catch {
            fatalError("TODO couche Erreurs")
        }
        return try Self.recap(from: response)
    }

    /// Consignes avec le prompt et le playbook du profil à leurs emplacements. Logique pure.
    static func systemPrompt(instructions: String, profile: SavedCall.Profile) -> String {
        SystemPrompt.text(frame: instructions, prompt: profile.prompt, playbook: Playbook(markdown: profile.playbook))
    }

    /// Transcription envoyée à Claude, une réplique par ligne : « [04:12] Moi : … ». Logique pure.
    static func transcriptText(of call: SavedCall) -> String {
        call.transcript
            .map { line in
                let speaker = line.speaker == .me ? "Moi" : "Interlocuteur"
                return "[\(CallTime.label(line.start))] \(speaker) : \(line.text)"
            }
            .joined(separator: "\n")
    }

    /// Compte rendu lu dans la réponse JSON de Claude, entre sa première et sa dernière accolade : Claude l'entoure
    /// parfois d'un bloc de code. Logique pure.
    static func recap(from response: String) throws(CallArchiveError) -> CallRecap {
        guard let start = response.firstIndex(of: "{"), let end = response.lastIndex(of: "}"), start < end,
              let answer = try? JSONDecoder().decode(Answer.self, from: Data(response[start...end].utf8))
        else {
            fatalError("TODO couche Erreurs")
        }
        return CallRecap(
            title: answer.title,
            summary: CallRecap.Summary(
                overview: answer.summary.overview,
                keyPoints: answer.summary.keyPoints,
                nextSteps: answer.summary.nextSteps
            ),
            debrief: CallRecap.Debrief(
                strengths: answer.debrief.strengths,
                improvements: answer.debrief.improvements.map { improvement in
                    CallRecap.Improvement(
                        issue: improvement.issue,
                        moment: improvement.moment.flatMap(CallTime.seconds(from:)),
                        quote: improvement.quote,
                        betterPhrasing: improvement.betterPhrasing
                    )
                }
            )
        )
    }

    /// Réponse de Claude, telle que `call-recap.md` la demande. Le moment est un libellé « 04:12 ».
    private struct Answer: Decodable {
        struct Summary: Decodable {
            let overview: String
            let keyPoints: [String]
            let nextSteps: [String]
        }

        struct Improvement: Decodable {
            let issue: String
            let moment: String?
            let quote: String?
            let betterPhrasing: String
        }

        struct Debrief: Decodable {
            let strengths: [String]
            let improvements: [Improvement]
        }

        let title: String
        let summary: Summary
        let debrief: Debrief
    }
}
