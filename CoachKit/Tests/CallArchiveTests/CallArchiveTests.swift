import Foundation
import Testing
@testable import CallArchive

/// Erreur de la fausse écriture de compte rendu.
private struct RecapUnavailable: LocalizedError {
    var errorDescription: String? { "Claude a renvoyé une erreur : limite d'usage" }
}

/// Archive dans un dossier temporaire, avec une fausse écriture du compte rendu.
private final class Fixture {
    let temporaryDirectory: TemporaryDirectory
    let archive: CallArchive

    init(
        now: Date = date("2026-11-06T19:00:00+01:00"),
        writeRecap: @escaping @Sendable (SavedCall) async throws -> CallRecap = { _ in sampleRecap }
    ) throws {
        temporaryDirectory = try TemporaryDirectory()
        archive = CallArchive(directory: temporaryDirectory.url.appending(component: "Calls"), now: { now }, writeRecap: writeRecap)
    }

    var directory: URL { temporaryDirectory.url.appending(component: "Calls") }

    /// Fichier écrit à la main, comme un call d'un lancement précédent.
    func write(_ call: SavedCall) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(call).write(to: directory.appending(component: "\(call.id.uuidString).json"))
    }

    func status(of call: SavedCall) async -> SavedCall.RecapStatus? {
        await archive.calls().first { $0.id == call.id }?.recapStatus
    }

    func hasFile(of call: SavedCall) -> Bool {
        FileManager.default.fileExists(atPath: directory.appending(component: "\(call.id.uuidString).json").path)
    }
}

struct CallArchiveTests {
    // MARK: Enregistrement et compte rendu

    @Test func recordedCallGetsItsRecapWritten() async throws {
        let fixture = try Fixture()
        let call = makeCall()

        try await fixture.archive.record(call)

        #expect(await eventually { await fixture.status(of: call) == .written(recap: sampleRecap) })
        #expect(await fixture.archive.calls().first?.transcript == call.transcript)
    }

    @Test func callIsSavedBeforeItsRecapIsWritten() async throws {
        let gate = Gate()
        let fixture = try Fixture { _ in
            await gate.wait()
            return sampleRecap
        }
        let call = makeCall()

        try await fixture.archive.record(call)

        #expect(await fixture.status(of: call) == .writing)
        await gate.open()
        #expect(await eventually { await fixture.status(of: call) == .written(recap: sampleRecap) })
    }

    @Test func failedRecapKeepsTheCallWithItsReason() async throws {
        let fixture = try Fixture { _ in throw RecapUnavailable() }
        let call = makeCall()

        try await fixture.archive.record(call)

        #expect(await eventually { await fixture.status(of: call) == .failed(reason: "Claude a renvoyé une erreur : limite d'usage") })
    }

    @Test func retryWritesTheRecapOfAFailedCall() async throws {
        let fixture = try Fixture()
        let call = makeCall(recapStatus: .failed(reason: "réseau coupé"))
        try fixture.write(call)

        await fixture.archive.retryRecap(of: call.id)

        #expect(await eventually { await fixture.status(of: call) == .written(recap: sampleRecap) })
    }

    @Test func callDeletedWhileItsRecapIsWrittenIsNotRecreated() async throws {
        let gate = Gate()
        let fixture = try Fixture { _ in
            await gate.wait()
            return sampleRecap
        }
        let call = makeCall()
        try await fixture.archive.record(call)

        try await fixture.archive.delete(call.id)
        await gate.open()
        try await Task.sleep(for: .milliseconds(200))

        #expect(!fixture.hasFile(of: call))
    }

    @Test func callThatCannotBeSavedIsReported() async throws {
        let fixture = try Fixture()
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: fixture.directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fixture.directory.path) }

        let error = await #expect(throws: CallArchiveError.self) { try await fixture.archive.record(makeCall()) }

        guard case .some(.saveFailed) = error else {
            Issue.record("Erreur inattendue : \(String(describing: error))")
            return
        }
    }

    // MARK: Liste

    @Test func callsAreListedFromTheMostRecentAndUnreadableFilesAreSkipped() async throws {
        let fixture = try Fixture()
        let older = makeCall(startDate: date("2026-11-03T10:00:00+01:00"), recapStatus: .written(recap: sampleRecap))
        let recent = makeCall(startDate: date("2026-11-06T16:20:00+01:00"), recapStatus: .written(recap: sampleRecap))
        try fixture.write(older)
        try fixture.write(recent)
        try Data("pas un call".utf8).write(to: fixture.directory.appending(component: "illisible.json"))

        #expect(await fixture.archive.calls().map(\.id) == [recent.id, older.id])
    }

    @Test func noCallBeforeTheFolderExists() async throws {
        let fixture = try Fixture()

        #expect(await fixture.archive.calls().isEmpty)
    }

    // MARK: Lancement et conservation

    @Test func recapLeftWritingByAPreviousLaunchCanBeRetried() async throws {
        let fixture = try Fixture()
        let call = makeCall(recapStatus: .writing)
        try fixture.write(call)

        await fixture.archive.start()

        #expect(await fixture.status(of: call) == .failed(reason: "L'écriture a été interrompue par la fermeture de l'app."))
    }

    @Test func callsOlderThanSixMonthsAreDeletedAtLaunch() async throws {
        let fixture = try Fixture(now: date("2026-11-06T19:00:00+01:00"))
        let expired = makeCall(startDate: date("2026-05-06T10:00:00+02:00"), recapStatus: .written(recap: sampleRecap))
        let kept = makeCall(startDate: date("2026-05-07T10:00:00+02:00"), recapStatus: .written(recap: sampleRecap))
        try fixture.write(expired)
        try fixture.write(kept)

        await fixture.archive.start()

        #expect(await fixture.archive.calls().map(\.id) == [kept.id])
    }

    @Test func expiredCallsAreAlsoDeletedWhenACallIsRecorded() async throws {
        let fixture = try Fixture(now: date("2026-11-06T19:00:00+01:00"))
        let expired = makeCall(startDate: date("2026-01-10T10:00:00+01:00"), recapStatus: .written(recap: sampleRecap))
        try fixture.write(expired)

        try await fixture.archive.record(makeCall())

        #expect(!fixture.hasFile(of: expired))
    }

    @Test func callIsExpiredExactlySixMonthsAfterIt() {
        let call = makeCall(startDate: date("2026-05-06T19:00:00+02:00"))

        #expect(CallArchive.isExpired(call, now: date("2026-11-06T19:00:00+01:00"), calendar: paris))
        #expect(!CallArchive.isExpired(call, now: date("2026-11-05T19:00:00+01:00"), calendar: paris))
    }

    // MARK: Suppression

    @Test func deletedCallDisappears() async throws {
        let fixture = try Fixture()
        let call = makeCall(recapStatus: .written(recap: sampleRecap))
        try fixture.write(call)

        try await fixture.archive.delete(call.id)

        #expect(!fixture.hasFile(of: call))
    }

    @Test func deletingACallThatIsAlreadyGoneIsNotAFailure() async throws {
        let fixture = try Fixture()

        try await fixture.archive.delete(UUID())
    }

    @Test func deletionFailureIsReported() async throws {
        let fixture = try Fixture()
        let call = makeCall(recapStatus: .written(recap: sampleRecap))
        try fixture.write(call)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: fixture.directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fixture.directory.path) }

        let error = await #expect(throws: CallArchiveError.self) { try await fixture.archive.delete(call.id) }

        guard case .some(.deleteFailed) = error else {
            Issue.record("Erreur inattendue : \(String(describing: error))")
            return
        }
    }
}
