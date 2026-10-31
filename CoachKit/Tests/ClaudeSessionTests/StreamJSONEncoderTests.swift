import Foundation
import Testing
@testable import ClaudeSession

struct StreamJSONEncoderTests {
    let encoder = StreamJSONEncoder()

    @Test func promptBecomesUserMessageLine() throws {
        #expect(try encoder.line(for: "Bonjour") == #"{"message":{"content":"Bonjour","role":"user"},"type":"user"}"#)
    }

    @Test func promptStaysOnOneLineAndRoundTrips() throws {
        let prompt = "Prospect : « c'est trop cher »\nMoi : \"d'accord\" / on en parle"

        let line = try encoder.line(for: prompt)

        #expect(!line.contains("\n"))
        let decoded = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        let message = decoded?["message"] as? [String: Any]
        #expect(message?["content"] as? String == prompt)
    }

    @Test func interruptLineMatchesSDKProtocol() throws {
        #expect(try encoder.interruptLine(requestID: "interrupt-1")
            == #"{"request":{"subtype":"interrupt"},"request_id":"interrupt-1","type":"control_request"}"#)
    }
}
