import Testing
@testable import Prompting

/// Consignes du coach avec l'emplacement du playbook, comme dans `coach-system.md`.
private let instructions = """
    Tu es un coach.

    <playbook>
    {{playbook}}
    </playbook>

    Réponds court.
    """

struct SystemPromptTests {
    @Test func playbookTakesThePlaceOfThePlaceholder() {
        let text = SystemPrompt.text(instructions: instructions, playbook: Playbook(markdown: "## Pricing\n49 € par mois"))

        #expect(text == """
            Tu es un coach.

            <playbook>
            ## Pricing
            49 € par mois
            </playbook>

            Réponds court.
            """)
    }

    @Test func blankLinesAroundThePlaybookAreRemoved() {
        let text = SystemPrompt.text(instructions: instructions, playbook: Playbook(markdown: "\n\n## Pricing\n\n"))

        #expect(text.contains("<playbook>\n## Pricing\n</playbook>"))
    }

    @Test func callWithoutPlaybookLeavesItsPlaceEmpty() {
        let text = SystemPrompt.text(instructions: instructions, playbook: Playbook(markdown: ""))

        #expect(text.contains("<playbook>\n\n</playbook>"))
        #expect(!text.contains("{{playbook}}"))
    }

    @Test func playbookIsAppendedWhenTheInstructionsHaveNoPlaceholder() {
        let text = SystemPrompt.text(instructions: "Tu es un coach.", playbook: Playbook(markdown: "## Pricing"))

        #expect(text == "Tu es un coach.\n\n## Pricing")
    }
}
