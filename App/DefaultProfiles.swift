import Prompting

/// Profils créés au premier lancement, ou quand l'utilisateur les a tous supprimés. Le premier devient actif.
enum DefaultProfiles {
    static var all: KeyValuePairs<String, ProfileContent> {
        [
            "Vente": ProfileContent(
                prompt: BundledPrompt.text(named: "default-sales-prompt"),
                playbook: BundledPrompt.text(named: "default-sales-playbook")
            ),
            "Entretien": ProfileContent(
                prompt: BundledPrompt.text(named: "default-interview-prompt"),
                playbook: BundledPrompt.text(named: "default-interview-playbook")
            ),
        ]
    }
}
