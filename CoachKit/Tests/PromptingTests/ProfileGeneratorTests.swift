import Foundation
import Testing
@testable import Prompting

struct ProfileGeneratorTests {
    @Test func promptAndPlaybookAreReadFromTheirBlocks() throws {
        let response = """
            Voici le profil.
            <prompt>

            Tu es un coach de négociation.
            Format de réponse, en français.

            </prompt>
            <playbook>
            # Playbook

            ## Offre reçue
            </playbook>
            Bonne négociation !
            """

        let content = try ProfileGenerator.content(from: response)

        #expect(content == ProfileContent(
            prompt: "Tu es un coach de négociation.\nFormat de réponse, en français.",
            playbook: "# Playbook\n\n## Offre reçue"
        ))
    }

    @Test func missingPlaybookGivesAnEmptyPlaybook() throws {
        let content = try ProfileGenerator.content(from: "<prompt>Tu es un coach.</prompt>")

        #expect(content == ProfileContent(prompt: "Tu es un coach.", playbook: ""))
    }

    @Test func closingTagBeforeTheOpeningOneIsIgnored() throws {
        let content = try ProfileGenerator.content(from: "Fin du bloc </prompt> puis <prompt>Tu es un coach.</prompt>")

        #expect(content.prompt == "Tu es un coach.")
    }

    @Test(arguments: [
        "Je ne peux pas écrire ce profil.",
        "<prompt>\n\n</prompt>",
        "<prompt>Tu es un coach, sans fin de bloc",
        "<playbook># Playbook</playbook>",
    ])
    func responseWithoutAUsablePromptIsRefused(response: String) {
        #expect(throws: PromptingError.generationInvalid) { try ProfileGenerator.content(from: response) }
    }

    @Test func tooLongPromptIsRefused() {
        let prompt = String(repeating: "a", count: Profile.maximumPromptLength + 1)

        #expect(throws: PromptingError.generationInvalid) { try ProfileGenerator.content(from: "<prompt>\(prompt)</prompt>") }
    }
}
