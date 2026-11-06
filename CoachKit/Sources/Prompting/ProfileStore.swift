import Foundation

/// Profils enregistrés dans `~/Library/Application Support/NotchCoach/Profils/`, un dossier par profil, et le profil
/// actif, gardé d'un lancement à l'autre.
public struct ProfileStore {
    /// `~/Library/Application Support/NotchCoach/Profils/` : l'app n'est pas sandboxée.
    public static let standardDirectory = URL.applicationSupportDirectory.appending(components: "NotchCoach", "Profils")
    /// Nom du profil actif dans les réglages de l'app.
    static let activeProfileKey = "ActiveProfile"

    /// Dossier qui contient un dossier par profil.
    public let directory: URL
    private let userDefaults: UserDefaults

    public init(directory: URL = ProfileStore.standardDirectory, userDefaults: UserDefaults = .standard) {
        self.directory = directory
        self.userDefaults = userDefaults
    }

    /// Crée les profils `defaults`, dans cet ordre, si aucun profil n'existe : au premier lancement, ou si l'utilisateur
    /// les a tous supprimés. Un profil supprimé alors que d'autres restent n'est pas recréé. Le premier devient actif.
    public func createDefaultsIfEmpty(_ defaults: KeyValuePairs<String, ProfileContent>) throws(PromptingError) {
        guard profiles().isEmpty else { return }
        var created: [Profile] = []
        for (name, content) in defaults {
            created.append(try create(named: name, content: content))
        }
        if let first = created.first {
            activate(first)
        }
    }

    /// Profils enregistrés, triés par nom. Un dossier sans `prompt.md` n'est pas un profil.
    public func profiles() -> [Profile] {
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []
        return folders
            .map { Profile(name: $0.lastPathComponent, directory: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.promptURL.path) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Profil choisi dans le menu. S'il n'existe plus, le premier des profils ; `nil` s'il n'y en a aucun.
    public func activeProfile() -> Profile? {
        let profiles = profiles()
        let name = userDefaults.string(forKey: Self.activeProfileKey)
        return profiles.first { $0.name == name } ?? profiles.first
    }

    /// Fait de `profile` le profil actif, pour ce lancement et les suivants.
    public func activate(_ profile: Profile) {
        userDefaults.set(profile.name, forKey: Self.activeProfileKey)
    }

    /// Crée un profil `name` avec `content`. Un profil existant n'est jamais écrasé.
    public func create(named name: String, content: ProfileContent) throws(PromptingError) -> Profile {
        let profile = Profile(name: name, directory: directory.appending(component: name, directoryHint: .isDirectory))
        do {
            try FileManager.default.createDirectory(at: profile.directory, withIntermediateDirectories: true)
            // Le prompt en dernier : tant qu'il manque, le dossier n'est pas un profil.
            try Data(content.playbook.utf8).write(to: profile.playbookURL, options: .withoutOverwriting)
            try Data(content.prompt.utf8).write(to: profile.promptURL, options: .withoutOverwriting)
        } catch {
            fatalError("TODO couche Erreurs")
        }
        return profile
    }
}
