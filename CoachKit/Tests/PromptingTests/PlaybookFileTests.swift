import Foundation
import Testing
@testable import Prompting

private let template = "# Playbook\n\n## Offre\n\n## Pricing\n"

/// Playbook à l'emplacement prévu par l'app : un dossier `NotchCoach` qui n'existe pas encore.
private func playbookFile(in directory: TemporaryDirectory) -> PlaybookFile {
    PlaybookFile(url: directory.url.appending(components: "NotchCoach", "playbook.md"), template: template)
}

/// Écrit le fichier, comme l'utilisateur l'aurait enregistré.
private func write(_ data: Data, to file: PlaybookFile) throws {
    try FileManager.default.createDirectory(at: file.url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: file.url)
}

private func contents(of file: PlaybookFile) throws -> String {
    try String(contentsOf: file.url, encoding: .utf8)
}

struct PlaybookFileTests {
    // MARK: Création

    @Test func createsTheMissingFileAndItsFolderFromTheTemplate() throws {
        let directory = try TemporaryDirectory()
        let file = playbookFile(in: directory)

        try file.createIfMissing()

        #expect(try contents(of: file) == template)
    }

    @Test func neverModifiesAnExistingFile() throws {
        let directory = try TemporaryDirectory()
        let file = playbookFile(in: directory)
        try write(Data("## Pricing\n49 € par mois\n".utf8), to: file)

        try file.createIfMissing()

        #expect(try contents(of: file) == "## Pricing\n49 € par mois\n")
    }

    @Test func creationFailureIsReported() throws {
        let directory = try TemporaryDirectory()
        let file = playbookFile(in: directory)
        // Dossier parent en lecture seule : le dossier `NotchCoach` ne peut pas y être créé.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.url.path) }

        let error = #expect(throws: PromptingError.self) { try file.createIfMissing() }

        guard case .some(.playbookCreationFailed) = error else {
            Issue.record("Erreur inattendue : \(String(describing: error))")
            return
        }
    }

    // MARK: Lecture

    @Test func loadCreatesTheMissingFileThenReadsIt() throws {
        let directory = try TemporaryDirectory()
        let file = playbookFile(in: directory)

        #expect(try file.load() == Playbook(markdown: template))
        #expect(try contents(of: file) == template)
    }

    @Test func loadReadsTheUserPlaybookAsItIs() throws {
        let directory = try TemporaryDirectory()
        let file = playbookFile(in: directory)
        try write(Data("## Pricing\n49 € par mois\n".utf8), to: file)

        #expect(try file.load() == Playbook(markdown: "## Pricing\n49 € par mois\n"))
    }

    @Test func unreadableFileIsReported() throws {
        let directory = try TemporaryDirectory()
        let file = playbookFile(in: directory)
        // Un dossier à la place du fichier : il existe, mais ne se lit pas.
        try FileManager.default.createDirectory(at: file.url, withIntermediateDirectories: true)

        let error = #expect(throws: PromptingError.self) { try file.load() }

        guard case .some(.playbookUnreadable) = error else {
            Issue.record("Erreur inattendue : \(String(describing: error))")
            return
        }
    }

    @Test func fileNotSavedAsUTF8IsReported() throws {
        let directory = try TemporaryDirectory()
        let file = playbookFile(in: directory)
        // Latin-1, l'encodage d'anciens éditeurs : « É » y tient sur un octet, invalide en UTF-8.
        try write(#require("Équipe : 49 euros par mois".data(using: .isoLatin1)), to: file)

        #expect(throws: PromptingError.playbookNotUTF8) { try file.load() }
    }

    @Test func playbookUpToTheMaximumLengthIsAccepted() throws {
        let directory = try TemporaryDirectory()
        let file = playbookFile(in: directory)
        // Des caractères, pas des octets : « é » en prend deux en UTF-8.
        let markdown = String(repeating: "é", count: PlaybookFile.maximumLength)
        try write(Data(markdown.utf8), to: file)

        #expect(try file.load() == Playbook(markdown: markdown))
    }

    @Test func playbookLongerThanTheMaximumIsReported() throws {
        let directory = try TemporaryDirectory()
        let file = playbookFile(in: directory)
        try write(Data(String(repeating: "é", count: PlaybookFile.maximumLength + 1).utf8), to: file)

        #expect(throws: PromptingError.playbookTooLong(characterCount: 50_001, limit: 50_000)) { try file.load() }
    }
}
