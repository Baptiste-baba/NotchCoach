import Foundation
import Testing
@testable import CallArchive

struct SavedCallTests {
    // MARK: Réplique citée

    @Test func quotedMomentFindsTheLineThatStartsAtThatSecond() {
        // La réplique commence à 47,9 s : le débrief la cite à « 00:47 ».
        #expect(makeCall().lineIndex(at: 47) == 1)
    }

    @Test func momentInsideALineFindsThatLine() {
        #expect(makeCall().lineIndex(at: 30) == 0)
    }

    @Test func momentBeforeTheFirstLineFindsNone() {
        #expect(makeCall().lineIndex(at: 3) == nil)
    }

    // MARK: Fichier

    @Test(arguments: [
        SavedCall.RecapStatus.writing,
        .written(recap: sampleRecap),
        .failed(reason: "Claude a renvoyé une erreur : limite d'usage atteinte"),
    ])
    func callIsReadBackAsWritten(status: SavedCall.RecapStatus) throws {
        let call = makeCall(recapStatus: status)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        #expect(try decoder.decode(SavedCall.self, from: encoder.encode(call)) == call)
    }

    @Test func writtenRecapIsStoredUnderARecapKey() throws {
        let json = String(decoding: try JSONEncoder().encode(SavedCall.RecapStatus.written(recap: sampleRecap)), as: UTF8.self)

        #expect(json.hasPrefix(#"{"written":{"recap":"#))
    }
}
