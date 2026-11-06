import Foundation

/// Profils enregistrés dans `~/Library/Application Support/NotchCoach/Profils/`, un dossier par profil, et le profil
/// actif, gardé d'un lancement à l'autre.
public struct ProfileStore {
    /// `~/Library/Application Support/NotchCoach/Profils/` : l'app n'est pas sandboxée.
    public static let standardDirectory = URL.applicationSupportDirectory.appending(components: "NotchCoach", "Profils")
    /// Nom du profil actif dans les réglages de l'app.
    static let activeProfileKey = "ActiveProfile"
    /// Un nom de menu, pas une phrase.
    static let maximumNameLength = 50

    /// Dossier qui contient un dossier par profil.
    public let directory: URL
    private let userDefaults: UserDefaults

    public init(directory: URL = ProfileStore.standardDirectory, userDefaults: UserDefaults = .standard) {
        self.directory = directory
        self.userDefaults = userDefaults
    }

    /// Crée les profils `defaults`, dans cet ordre, si aucun profil n'existe : au premier lancement, ou si l'utilisateur
    /// les a tous supprimés. Un profil supprimé alors que d'autres restent n'est pas recréé. Le premier créé devient
    /// actif. Un dossier qui porte déjà le nom d'un profil fourni n'est jamais écrasé : ce profil est sauté.
    public func createDefaultsIfEmpty(_ defaults: KeyValuePairs<String, ProfileContent>) throws(PromptingError) {
        guard profiles().isEmpty else { return }
        var created: [Profile] = []
        for (name, content) in defaults {
            guard !FileManager.default.fileExists(atPath: directory.appending(component: name).path) else { continue }
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

    /// Vérifie qu'un profil peut être créé sous ce nom : il doit pouvoir devenir celui d'un dossier, et n'être pris ni
    /// par un profil ni par un autre dossier.
    public func checkNewProfileName(_ name: String) throws(PromptingError) {
        let isHidden = name.hasPrefix(".")
        let hasForbiddenCharacter = name.contains("/") || name.contains(":")
            || name.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
        let isBlank = name.trimmingCharacters(in: .whitespaces).isEmpty
        guard !isBlank, !isHidden, !hasForbiddenCharacter, name.count <= Self.maximumNameLength else {
            throw .invalidProfileName(name)
        }
        // Le système de fichiers ignore la casse : « vente » existe déjà si « Vente » existe.
        guard !FileManager.default.fileExists(atPath: directory.appending(component: name).path) else {
            throw .profileAlreadyExists(name)
        }
    }

    /// Crée un profil `name` avec `content`. Un profil existant n'est jamais écrasé, et un profil à moitié écrit est
    /// effacé : il bloquerait son nom.
    public func create(named name: String, content: ProfileContent) throws(PromptingError) -> Profile {
        try checkNewProfileName(name)
        let profile = Profile(name: name, directory: directory.appending(component: name, directoryHint: .isDirectory))
        do {
            try FileManager.default.createDirectory(at: profile.directory, withIntermediateDirectories: true)
            // Le prompt en dernier : tant qu'il manque, le dossier n'est pas un profil.
            try Data(content.playbook.utf8).write(to: profile.playbookURL, options: .withoutOverwriting)
            try Data(content.prompt.utf8).write(to: profile.promptURL, options: .withoutOverwriting)
        } catch {
            try? FileManager.default.removeItem(at: profile.directory)
            throw .profileCreationFailed(reason: error.localizedDescription)
        }
        return profile
    }
}
