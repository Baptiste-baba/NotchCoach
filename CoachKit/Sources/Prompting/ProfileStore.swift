import Foundation

/// Profils enregistrés dans `~/Library/Application Support/NotchCoach/Profils/`, un dossier par profil, et le profil
/// actif, gardé d'un lancement à l'autre.
public struct ProfileStore {
    /// `~/Library/Application Support/NotchCoach/Profils/` : l'app n'est pas sandboxée.
    public static let standardDirectory = URL.applicationSupportDirectory.appending(components: "NotchCoach", "Profils")

    /// Dossier qui contient un dossier par profil.
    public let directory: URL
    private let userDefaults: UserDefaults

    public init(directory: URL = ProfileStore.standardDirectory, userDefaults: UserDefaults = .standard) {
        self.directory = directory
        self.userDefaults = userDefaults
    }

    /// Crée les profils `defaults`, dans cet ordre, si aucun profil n'existe : au premier lancement, ou si l'utilisateur
    /// les a tous supprimés. Un profil supprimé alors que d'autres restent n'est pas recréé.
    public func createDefaultsIfEmpty(_ defaults: KeyValuePairs<String, ProfileContent>) throws(PromptingError) {
        fatalError("TODO")
    }

    /// Profils enregistrés, triés par nom.
    public func profiles() -> [Profile] {
        fatalError("TODO")
    }

    /// Profil choisi dans le menu. S'il n'existe plus, le premier des profils ; `nil` s'il n'y en a aucun.
    public func activeProfile() -> Profile? {
        fatalError("TODO")
    }

    /// Fait de `profile` le profil actif, pour ce lancement et les suivants.
    public func activate(_ profile: Profile) {
        fatalError("TODO")
    }

    /// Crée un profil `name` avec `content`. Un profil existant n'est jamais écrasé.
    public func create(named name: String, content: ProfileContent) throws(PromptingError) -> Profile {
        fatalError("TODO")
    }
}
