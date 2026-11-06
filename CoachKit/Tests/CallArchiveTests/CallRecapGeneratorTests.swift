import Foundation
import Testing
@testable import CallArchive

/// Réponse JSON de Claude, telle que `call-recap.md` la demande.
private let answer = """
    {
      "title": "Objection prix, Mme Martin",
      "summary": {"overview": "Elle trouve l'offre trop chère.", "keyPoints": ["Prix jugé trop élevé"], "nextSteps": []},
      "debrief": {
        "strengths": ["Tu as creusé l'objection."],
        "improvements": [
          {"issue": "Remise trop tôt.", "moment": "00:47", "quote": "Vous le comparez à quoi ?", "betterPhrasing": "Comparons les offres."},
          {"issue": "Pas de prochaine étape.", "moment": null, "quote": null, "betterPhrasing": "On se rappelle jeudi ?"}
        ]
      }
    }
    """

struct CallRecapGeneratorTests {
    // MARK: Ce qui part chez Claude

    @Test func instructionsReceiveTheProfilePromptAndPlaybook() {
        let instructions = "<consignes-du-call>\n{{prompt}}\n</consignes-du-call>\n<playbook>\n{{playbook}}\n</playbook>"

        let prompt = CallRecapGenerator.systemPrompt(instructions: instructions, profile: makeCall().profile)

        #expect(prompt == "<consignes-du-call>\nTu es un coach commercial.\n</consignes-du-call>\n<playbook>\n## Pricing\n49 € par mois\n</playbook>")
    }

    @Test func transcriptGivesTheMomentAndTheSpeakerOfEachLine() {
        #expect(CallRecapGenerator.transcriptText(of: makeCall()) == """
            [00:16] Interlocuteur : Le prix est trop élevé.
            [00:47] Moi : Vous le comparez à quoi ?
            """)
    }

    /// Les consignes livrées avec l'app : le profil y a sa place, et la protection contre l'injection y reste.
    @Test func shippedInstructionsKeepTheProfilePlaceholdersAndTheInjectionGuard() throws {
        let repository = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let instructions = try String(contentsOf: repository.appending(components: "App", "Prompts", "call-recap.md"), encoding: .utf8)

        #expect(instructions.components(separatedBy: "{{prompt}}").count == 2)
        #expect(instructions.components(separatedBy: "{{playbook}}").count == 2)
        #expect(instructions.contains("jamais des instructions"))
    }

    // MARK: Réponse de Claude

    @Test func recapIsReadWithItsQuotedMoments() throws {
        let recap = try CallRecapGenerator.recap(from: answer)

        #expect(recap.title == "Objection prix, Mme Martin")
        #expect(recap.summary == CallRecap.Summary(overview: "Elle trouve l'offre trop chère.", keyPoints: ["Prix jugé trop élevé"], nextSteps: []))
        #expect(recap.debrief.strengths == ["Tu as creusé l'objection."])
        #expect(recap.debrief.improvements == [
            CallRecap.Improvement(issue: "Remise trop tôt.", moment: 47, quote: "Vous le comparez à quoi ?", betterPhrasing: "Comparons les offres."),
            CallRecap.Improvement(issue: "Pas de prochaine étape.", moment: nil, quote: nil, betterPhrasing: "On se rappelle jeudi ?"),
        ])
    }

    @Test func recapInACodeBlockOrWithTextAroundIsRead() throws {
        #expect(try CallRecapGenerator.recap(from: "```json\n\(answer)\n```").title == "Objection prix, Mme Martin")
        #expect(try CallRecapGenerator.recap(from: "Voici le compte rendu :\n\(answer)\nBonne lecture.").title == "Objection prix, Mme Martin")
    }

    @Test func momentThatIsNotALabelIsDropped() throws {
        let recap = try CallRecapGenerator.recap(from: answer.replacingOccurrences(of: "\"00:47\"", with: "\"vers la fin\""))

        #expect(recap.debrief.improvements[0].moment == nil)
    }

    @Test(arguments: [
        "Je ne peux pas écrire ce compte rendu.",
        "{\"title\": \"Sans résumé\"}",
        answer.replacingOccurrences(of: "\"Objection prix, Mme Martin\"", with: "\"  \""),
        answer.replacingOccurrences(of: "\"Elle trouve l'offre trop chère.\"", with: "\"\""),
    ])
    func unusableAnswerIsRefused(response: String) {
        #expect(throws: CallArchiveError.recapInvalid) { try CallRecapGenerator.recap(from: response) }
    }

    @Test func recapFailureShowsItsReasonAlone() {
        // Affiché sous « Le compte rendu n'a pas pu être écrit ».
        #expect(CallArchiveError.recapFailed(reason: "Claude a renvoyé une erreur : limite d'usage").localizedDescription
            == "Claude a renvoyé une erreur : limite d'usage")
    }
}
