import Testing
@testable import ClaudeSession

struct StreamJSONParserTests {
    let parser = StreamJSONParser()

    /// Régression : le `delta` d'un `message_delta` n'a pas de champ `type`. La ligne est valide et doit être
    /// ignorée, pas rejetée comme invalide.
    @Test func messageDeltaWithoutTypeIsIgnored() throws {
        let line = #"{"type":"stream_event","event":{"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null}},"session_id":"s","uuid":"u"}"#

        #expect(try parser.parse(line) == nil)
    }
}
