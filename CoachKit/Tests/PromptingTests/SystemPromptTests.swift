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
}
