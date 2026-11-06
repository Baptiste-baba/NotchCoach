/// Profils enregistrés à un instant, avec le profil actif, et la raison pour laquelle il n'y en a aucun.
public struct ProfileSnapshot: Equatable, Sendable {
    /// Profils triés par nom.
    public var profiles: [Profile] = []
    /// Profil du prochain call ; `nil` s'il n'y a aucun profil.
    public var activeProfile: Profile?
    /// Échec de la création des profils fournis, s'il a eu lieu.
    var defaultsCreationError: PromptingError?

    public init() {}

    init(profiles: [Profile], activeProfile: Profile?, defaultsCreationError: PromptingError?) {
        self.profiles = profiles
        self.activeProfile = activeProfile
        self.defaultsCreationError = defaultsCreationError
    }

    /// Pourquoi aucun profil n'est disponible, à montrer à l'utilisateur ; `nil` s'il y a un profil actif.
    public var unavailabilityReason: String? {
        guard activeProfile == nil else { return nil }
        return defaultsCreationError?.localizedDescription ?? "Le dossier des profils est vide."
    }
}
