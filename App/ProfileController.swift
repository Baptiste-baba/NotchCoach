import AppKit
import Observation
import Prompting

/// Actions du menu sur les profils : choisir le profil actif, ouvrir son prompt ou son playbook, en créer un nouveau.
@Observable
final class ProfileController {
    /// Profils enregistrés et profil actif : le sous-menu « Profil ».
    private(set) var snapshot = ProfileSnapshot()

    @ObservationIgnored private let store = ProfileStore()
    @ObservationIgnored private let generator = ProfileGenerator(instructions: BundledPrompt.text(named: "profile-generator"))
    @ObservationIgnored private var menuObserver: (any NSObjectProtocol)?

    init() {
        // Les profils sont relus à chaque ouverture du menu : l'utilisateur a pu en ajouter, en renommer ou en
        // supprimer dans le Finder.
        menuObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    /// Crée les profils fournis avec l'app s'il n'y en a aucun, puis relit ceux qui sont enregistrés : l'utilisateur a
    /// pu en renommer ou en supprimer dans le Finder.
    func reload() {
        snapshot = store.load(creatingIfEmpty: DefaultProfiles.all)
    }

    /// Profil actif, relu sur le disque : il a pu être renommé ou supprimé dans le Finder. S'il n'y en a aucun, une
    /// alerte en donne la raison.
    func requireActiveProfile() -> Profile? {
        reload()
        if let reason = snapshot.unavailabilityReason {
            showAlert("Aucun profil disponible", details: "\(reason)\n\n\(store.directory.path)")
        }
        return snapshot.activeProfile
    }

    func activate(_ profile: Profile) {
        store.activate(profile)
        snapshot.activeProfile = profile
    }

    /// Ouvre le prompt du profil actif dans l'éditeur par défaut.
    func editPrompt() {
        guard let activeProfile = requireActiveProfile() else { return }
        open(activeProfile.promptURL)
    }

    /// Ouvre le playbook du profil actif dans l'éditeur par défaut, après l'avoir recréé s'il a été supprimé.
    func editPlaybook() {
        guard let activeProfile = requireActiveProfile() else { return }
        do {
            try activeProfile.playbookFile.createIfMissing()
        } catch {
            showAlert("Impossible d'ouvrir le playbook", details: "\(error.localizedDescription)\n\n\(activeProfile.playbookURL.path)")
            return
        }
        open(activeProfile.playbookURL)
    }

    /// Fait écrire par Claude un profil `name` adapté à `description`, l'enregistre et en fait le profil actif, puis
    /// ouvre son playbook, à remplir. L'annulation de la tâche arrête Claude et lève `generationCancelled`.
    func createProfile(named name: String, description: String) async throws(PromptingError) {
        // Vérifié avant de faire attendre Claude pour un nom qui serait refusé.
        try store.checkNewProfileName(name)
        let content = try await generator.generate(description: description)
        let profile = try store.create(named: name, content: content)
        reload()
        activate(profile)
        open(profile.playbookURL)
    }

    private func open(_ url: URL) {
        // Sans éditeur pour les fichiers Markdown, le fichier est montré dans le Finder.
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func showAlert(_ message: String, details: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = details
        // L'app n'a pas de fenêtre : sans ça, l'alerte resterait derrière celle de l'app active.
        NSApp.activate()
        alert.runModal()
    }
}
