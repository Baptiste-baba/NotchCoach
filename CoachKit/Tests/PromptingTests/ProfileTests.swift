import Foundation
import Testing
@testable import Prompting

/// Profil « Vente » dans un dossier temporaire, avec son prompt tel que l'utilisateur l'a enregistré.
private func profile(in directory: TemporaryDirectory, prompt: Data?) throws -> Profile {
    let profile = Profile(name: "Vente", directory: directory.url.appending(component: "Vente"))
    try FileManager.default.createDirectory(at: profile.directory, withIntermediateDirectories: true)
    if let prompt {
        try prompt.write(to: profile.promptURL)
    }
    return profile
}

struct ProfileTests {
    // MARK: Prompt

    @Test func promptIsReadAsWritten() throws {
        let directory = try TemporaryDirectory()
        let profile = try profile(in: directory, prompt: Data("Tu es un coach commercial.\n".utf8))

        #expect(try profile.loadPrompt() == "Tu es un coach commercial.\n")
    }

    @Test func missingPromptIsUnreadable() throws {
        let directory = try TemporaryDirectory()
        let profile = try profile(in: directory, prompt: nil)

        let error = #expect(throws: PromptingError.self) { try profile.loadPrompt() }

        guard case .some(.promptUnreadable(profile: "Vente", _)) = error else {
            Issue.record("Erreur inattendue : \(String(describing: error))")
            return
        }
    }

    @Test func blankPromptIsRefused() throws {
        let directory = try TemporaryDirectory()
        let profile = try profile(in: directory, prompt: Data("  \n\n".utf8))

        #expect(throws: PromptingError.promptEmpty(profile: "Vente")) { try profile.loadPrompt() }
    }

    @Test func promptMustBeUTF8() throws {
        let directory = try TemporaryDirectory()
        // « é » en Latin-1 : un octet isolé, invalide en UTF-8.
        let profile = try profile(in: directory, prompt: Data([0x43, 0x61, 0x66, 0xE9]))

        #expect(throws: PromptingError.promptNotUTF8(profile: "Vente")) { try profile.loadPrompt() }
    }

    @Test func tooLongPromptIsRefused() throws {
        let directory = try TemporaryDirectory()
        let length = Profile.maximumPromptLength + 1
        let profile = try profile(in: directory, prompt: Data(String(repeating: "a", count: length).utf8))

        #expect(throws: PromptingError.promptTooLong(profile: "Vente", characterCount: length, limit: Profile.maximumPromptLength)) {
            try profile.loadPrompt()
        }
    }

    @Test func promptAtTheMaximumLengthIsAccepted() throws {
        let directory = try TemporaryDirectory()
        let prompt = String(repeating: "a", count: Profile.maximumPromptLength)
        let profile = try profile(in: directory, prompt: Data(prompt.utf8))

        #expect(try profile.loadPrompt() == prompt)
    }

    @Test func promptErrorNamesTheProfile() {
        // Affiché en rouge dans la notch quand le call ne peut pas démarrer.
        #expect(PromptingError.promptEmpty(profile: "Vente").localizedDescription == "Le prompt du profil « Vente » est vide.")
    }

    // MARK: Playbook

    @Test func deletedPlaybookIsRecreatedEmpty() throws {
        let directory = try TemporaryDirectory()
        let profile = try profile(in: directory, prompt: Data("Tu es un coach.".utf8))

        #expect(try profile.playbookFile.load() == Playbook(markdown: ""))
        #expect(FileManager.default.fileExists(atPath: profile.playbookURL.path))
    }
}
