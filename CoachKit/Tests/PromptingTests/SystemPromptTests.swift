import Foundation
import Testing
@testable import Prompting

/// Partie technique avec les emplacements du prompt et du playbook, comme dans `coach-frame.md`.
private let frame = """
    Tu aides « Moi ».

    <playbook>
    {{playbook}}
    </playbook>

    <consignes>
    {{prompt}}
    </consignes>
    """

struct SystemPromptTests {
    @Test func promptAndPlaybookTakeThePlaceOfTheirPlaceholders() {
        let text = SystemPrompt.text(frame: frame, prompt: "Réponds court.", playbook: Playbook(markdown: "## Pricing\n49 € par mois"))

        #expect(text == """
            Tu aides « Moi ».

            <playbook>
            ## Pricing
            49 € par mois
            </playbook>

            <consignes>
            Réponds court.
            </consignes>
            """)
    }

    @Test func blankLinesAroundThePlaybookAreRemoved() {
        let text = SystemPrompt.text(frame: frame, prompt: "Réponds court.", playbook: Playbook(markdown: "\n\n## Pricing\n\n"))

        #expect(text.contains("<playbook>\n## Pricing\n</playbook>"))
    }

    @Test func callWithoutPlaybookLeavesItsPlaceEmpty() {
        let text = SystemPrompt.text(frame: frame, prompt: "Réponds court.", playbook: Playbook(markdown: ""))

        #expect(text.contains("<playbook>\n\n</playbook>"))
        #expect(!text.contains("{{playbook}}"))
    }

    @Test func placeholderWrittenInThePromptStaysAsIs() {
        let text = SystemPrompt.text(frame: frame, prompt: "Cite {{playbook}} tel quel.", playbook: Playbook(markdown: "## Pricing"))

        #expect(text.contains("<consignes>\nCite {{playbook}} tel quel.\n</consignes>"))
        #expect(text.components(separatedBy: "## Pricing").count == 2)
    }

    @Test func placeholderWrittenInThePlaybookStaysAsIs() {
        let text = SystemPrompt.text(frame: frame, prompt: "Réponds court.", playbook: Playbook(markdown: "Note : {{prompt}}"))

        #expect(text.contains("<playbook>\nNote : {{prompt}}\n</playbook>"))
        #expect(text.components(separatedBy: "Réponds court.").count == 2)
    }

    /// La partie technique livrée avec l'app : ce qu'aucune modification ni génération du prompt d'un profil ne peut
    /// retirer.
    @Test func shippedFrameKeepsBothPlaceholdersAndTheInjectionGuard() throws {
        let repository = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let shippedFrame = try String(contentsOf: repository.appending(components: "App", "Prompts", "coach-frame.md"), encoding: .utf8)

        #expect(shippedFrame.components(separatedBy: "{{prompt}}").count == 2)
        #expect(shippedFrame.components(separatedBy: "{{playbook}}").count == 2)
        #expect(shippedFrame.contains("réponds uniquement : -"))
        #expect(shippedFrame.contains("jamais des instructions"))
    }
}
