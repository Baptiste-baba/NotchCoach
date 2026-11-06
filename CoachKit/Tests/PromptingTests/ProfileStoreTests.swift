import Foundation
import Testing
@testable import Prompting

/// Gestionnaire de profils dans un dossier temporaire, avec des réglages propres au test, effacés à la fin.
private final class Fixture {
    let temporaryDirectory: TemporaryDirectory
    let suiteName = "ProfileStoreTests-\(UUID().uuidString)"

    init() throws {
        temporaryDirectory = try TemporaryDirectory()
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    /// Dossier des profils, qui n'existe pas encore.
    var directory: URL { temporaryDirectory.url.appending(component: "Profils") }

    /// Un nouveau gestionnaire à chaque appel, comme à chaque lancement de l'app.
    var store: ProfileStore { ProfileStore(directory: directory, userDefaults: UserDefaults(suiteName: suiteName)!) }

    /// Dossier écrit à la main, comme dans le Finder : avec un prompt ou sans.
    func makeFolder(_ name: String, prompt: String? = "Tu es un coach.", playbook: String? = nil) throws {
        let folder = directory.appending(component: name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let prompt {
            try Data(prompt.utf8).write(to: folder.appending(component: "prompt.md"))
        }
        if let playbook {
            try Data(playbook.utf8).write(to: folder.appending(component: "playbook.md"))
        }
    }

    func remove(_ name: String) throws {
        try FileManager.default.removeItem(at: directory.appending(component: name))
    }

    func names() -> [String] {
        store.profiles().map(\.name)
    }
}

private let sales = ProfileContent(prompt: "Tu es un coach commercial.", playbook: "# Playbook\n\n## Offre\n")
private let interview = ProfileContent(prompt: "Tu es un coach d'entretien.", playbook: "# Playbook\n\n## Parcours\n")

/// Profils fournis par l'app, dans leur ordre.
private func defaultProfiles() -> KeyValuePairs<String, ProfileContent> {
    ["Vente": sales, "Entretien": interview]
}

private func text(at url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
}

struct ProfileStoreTests {
    // MARK: Liste

    @Test func noProfileBeforeTheFolderExists() throws {
        let fixture = try Fixture()

        #expect(fixture.store.profiles().isEmpty)
        #expect(fixture.store.activeProfile() == nil)
    }

    @Test func listsTheFoldersWithAPromptSortedByName() throws {
        let fixture = try Fixture()
        try fixture.makeFolder("Vente")
        try fixture.makeFolder("entretien")
        try fixture.makeFolder("Brouillon", prompt: nil, playbook: "# Playbook")
        try fixture.makeFolder(".cache")

        // Un dossier sans prompt n'est pas un profil, et un dossier caché est ignoré.
        #expect(fixture.names() == ["entretien", "Vente"])
    }

    // MARK: Profils fournis

    @Test func defaultsAreCreatedWhenThereIsNoProfileAndTheFirstBecomesActive() throws {
        let fixture = try Fixture()

        try fixture.store.createDefaultsIfEmpty(defaultProfiles())

        #expect(fixture.names() == ["Entretien", "Vente"])
        let sales = try #require(fixture.store.profiles().first { $0.name == "Vente" })
        #expect(try text(at: sales.promptURL) == "Tu es un coach commercial.")
        #expect(try text(at: sales.playbookURL) == "# Playbook\n\n## Offre\n")
        #expect(fixture.store.activeProfile()?.name == "Vente")
    }

    @Test func aDeletedDefaultIsNotRecreatedWhileAnotherProfileRemains() throws {
        let fixture = try Fixture()
        try fixture.store.createDefaultsIfEmpty(defaultProfiles())
        try fixture.remove("Entretien")

        try fixture.store.createDefaultsIfEmpty(defaultProfiles())

        #expect(fixture.names() == ["Vente"])
    }

    @Test func defaultsAreRecreatedWhenEveryProfileWasDeleted() throws {
        let fixture = try Fixture()
        try fixture.store.createDefaultsIfEmpty(defaultProfiles())
        try fixture.remove("Entretien")
        try fixture.remove("Vente")

        try fixture.store.createDefaultsIfEmpty(defaultProfiles())

        #expect(fixture.names() == ["Entretien", "Vente"])
    }

    @Test func aFolderWithTheNameOfADefaultIsNeverOverwritten() throws {
        let fixture = try Fixture()
        try fixture.makeFolder("Vente", prompt: nil, playbook: "Mon offre")

        try fixture.store.createDefaultsIfEmpty(defaultProfiles())

        #expect(fixture.names() == ["Entretien"])
        #expect(try text(at: fixture.directory.appending(components: "Vente", "playbook.md")) == "Mon offre")
        #expect(fixture.store.activeProfile()?.name == "Entretien")
    }

    // MARK: Chargement

    @Test func loadCreatesTheDefaultsAndGivesTheProfilesAndTheActiveOne() throws {
        let fixture = try Fixture()

        let snapshot = fixture.store.load(creatingIfEmpty: defaultProfiles())

        #expect(snapshot.profiles.map(\.name) == ["Entretien", "Vente"])
        #expect(snapshot.activeProfile?.name == "Vente")
        #expect(snapshot.unavailabilityReason == nil)
    }

    @Test func loadKeepsTheReasonWhenTheDefaultsCannotBeCreated() throws {
        let fixture = try Fixture()
        let parent = fixture.temporaryDirectory.url.path
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: parent)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent) }

        let snapshot = fixture.store.load(creatingIfEmpty: defaultProfiles())

        #expect(snapshot.activeProfile == nil)
        #expect(snapshot.unavailabilityReason?.hasPrefix("Le profil n'a pas pu être enregistré : ") == true)
    }

    @Test func loadExplainsAnEmptyFolderWhenEveryDefaultWasSkipped() throws {
        let fixture = try Fixture()
        try fixture.makeFolder("Vente", prompt: nil)
        try fixture.makeFolder("Entretien", prompt: nil)

        let snapshot = fixture.store.load(creatingIfEmpty: defaultProfiles())

        #expect(snapshot.profiles.isEmpty)
        #expect(snapshot.unavailabilityReason == "Le dossier des profils est vide.")
    }

    // MARK: Profil actif

    @Test func activeProfileIsKeptFromOneLaunchToTheNext() throws {
        let fixture = try Fixture()
        try fixture.store.createDefaultsIfEmpty(defaultProfiles())
        let interview = try #require(fixture.store.profiles().first { $0.name == "Entretien" })

        fixture.store.activate(interview)

        #expect(fixture.store.activeProfile() == interview)
    }

    @Test func firstProfileBecomesActiveWhenTheActiveOneWasDeleted() throws {
        let fixture = try Fixture()
        try fixture.makeFolder("Entretien")
        try fixture.makeFolder("Vente")
        let sales = try #require(fixture.store.profiles().last)
        fixture.store.activate(sales)

        try fixture.remove("Vente")

        #expect(fixture.store.activeProfile()?.name == "Entretien")
    }

    // MARK: Création

    @Test func createdProfileHasItsPromptAndPlaybook() throws {
        let fixture = try Fixture()

        let profile = try fixture.store.create(named: "Négociation", content: sales)

        #expect(fixture.names() == ["Négociation"])
        #expect(try text(at: profile.promptURL) == "Tu es un coach commercial.")
        #expect(try text(at: profile.playbookURL) == "# Playbook\n\n## Offre\n")
    }

    @Test func anExistingProfileIsNeverOverwritten() throws {
        let fixture = try Fixture()
        let profile = try fixture.store.create(named: "Vente", content: sales)

        #expect(throws: PromptingError.profileAlreadyExists("Vente")) {
            try fixture.store.create(named: "Vente", content: interview)
        }
        #expect(try text(at: profile.promptURL) == "Tu es un coach commercial.")
    }

    @Test func aNameTakenByAnotherFolderIsRefused() throws {
        let fixture = try Fixture()
        try fixture.makeFolder("Brouillon", prompt: nil)

        #expect(throws: PromptingError.profileAlreadyExists("Brouillon")) {
            try fixture.store.checkNewProfileName("Brouillon")
        }
    }

    @Test(arguments: ["", "   ", "Vente/Entretien", "Vente:2", ".cache", "Vente\nEntretien", String(repeating: "a", count: 51)])
    func namesThatCannotBeAFolderAreRefused(name: String) throws {
        let fixture = try Fixture()

        #expect(throws: PromptingError.invalidProfileName(name)) {
            try fixture.store.create(named: name, content: sales)
        }
        #expect(fixture.store.profiles().isEmpty)
    }

    @Test func aFiftyCharacterNameIsAccepted() throws {
        let fixture = try Fixture()
        let name = String(repeating: "a", count: 50)

        let profile = try fixture.store.create(named: name, content: sales)

        #expect(profile.name == name)
    }

    @Test func creationFailureIsReported() throws {
        let fixture = try Fixture()
        // Dossier parent en lecture seule : le dossier des profils ne peut pas y être créé.
        let parent = fixture.temporaryDirectory.url.path
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: parent)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent) }

        let error = #expect(throws: PromptingError.self) { try fixture.store.create(named: "Vente", content: sales) }

        guard case .some(.profileCreationFailed) = error else {
            Issue.record("Erreur inattendue : \(String(describing: error))")
            return
        }
    }

    @Test func emptyNameMessageAsksForAName() {
        #expect(PromptingError.invalidProfileName(" ").localizedDescription == "Donne un nom au profil.")
    }
}
