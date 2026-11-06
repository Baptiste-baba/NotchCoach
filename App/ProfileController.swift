import AppKit
import Observation
import Prompting

/// Actions du menu sur les profils : choisir le profil actif, ouvrir son prompt ou son playbook, en créer un nouveau.
@Observable
final class ProfileController {
    /// Profils enregistrés, triés par nom : le sous-menu « Profil ».
    private(set) var profiles: [Profile] = []
    /// Profil du prochain call ; `nil` s'il n'y en a aucun.
    private(set) var activeProfile: Profile?

    @ObservationIgnored private let store = ProfileStore()
    @ObservationIgnored private let generator = ProfileGenerator(instructions: BundledPrompt.text(named: "profile-generator"))

    /// Crée les profils fournis avec l'app s'il n'y en a aucun, puis relit ceux qui sont enregistrés : l'utilisateur a
    /// pu en renommer ou en supprimer dans le Finder.
    func reload() {
        fatalError("TODO")
    }

    func activate(_ profile: Profile) {
        fatalError("TODO")
    }

    /// Ouvre le prompt du profil actif dans l'éditeur par défaut.
    func editPrompt() {
        fatalError("TODO")
    }

    /// Ouvre le playbook du profil actif dans l'éditeur par défaut, après l'avoir recréé s'il a été supprimé.
    func editPlaybook() {
        fatalError("TODO")
    }

    /// Fait écrire par Claude un profil `name` adapté à `description`, l'enregistre et en fait le profil actif, puis
    /// ouvre son playbook, à remplir.
    func createProfile(named name: String, description: String) async throws(PromptingError) {
        fatalError("TODO")
    }
}
