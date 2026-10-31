import Testing
@testable import ClaudeSession

/// Lignes relevées sur Claude Code 2.1.310. Les plus longues sont abrégées aux champs utiles au décodage.
struct StreamJSONParserTests {
    let parser = StreamJSONParser()

    @Test func textDeltaGivesText() throws {
        let line = #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Bonjour"}},"session_id":"3efe0143-3468-42e0-81eb-1268bcbdb9a7","parent_tool_use_id":null,"uuid":"71591fbb-ba70-40fb-8808-9f85e2138083","api_message_id":"msg_011Cgakw9icBg5U4RHWbumwv"}"#

        #expect(try parser.parse(line) == .textDelta("Bonjour"))
    }

    @Test func successfulResultCompletes() throws {
        let line = #"{"type":"result","subtype":"success","is_error":false,"duration_ms":967,"num_turns":1,"result":"Bonjour","stop_reason":"end_turn","terminal_reason":"completed","session_id":"df84df3c-5c1c-4799-94f2-5a6e6995047e"}"#

        #expect(try parser.parse(line) == .completed)
    }

    @Test func errorResultFailsWithItsMessageDespiteSuccessSubtype() throws {
        let line = #"{"type":"result","subtype":"success","is_error":true,"api_error_status":null,"result":"Not logged in · Please run /login","terminal_reason":"api_error","session_id":"df84df3c-5c1c-4799-94f2-5a6e6995047e"}"#

        #expect(try parser.parse(line) == .failed(message: "Not logged in · Please run /login"))
    }

    @Test func interruptedResultFailsWithEmptyMessage() throws {
        let line = #"{"type":"result","subtype":"success","is_error":true,"result":"","stop_reason":null,"terminal_reason":"aborted_streaming","session_id":"d40c8eff-f6ba-4a9a-b314-72e645a57953"}"#

        #expect(try parser.parse(line) == .failed(message: ""))
    }

    /// Régression : le `delta` d'un `message_delta` n'a pas de champ `type`. La ligne est valide et doit être
    /// ignorée, pas rejetée comme invalide.
    @Test func messageDeltaWithoutTypeIsIgnored() throws {
        let line = #"{"type":"stream_event","event":{"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null}},"session_id":"s","uuid":"u"}"#

        #expect(try parser.parse(line) == nil)
    }

    @Test(arguments: [
        // Réflexion du modèle : jamais affichée.
        #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"","estimated_tokens":null}},"session_id":"d40c8eff","thinking_display":"updates"}"#,
        #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"EqoBCkgIBhAB"}},"session_id":"d40c8eff"}"#,
        #"{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}},"session_id":"3efe0143"}"#,
        #"{"type":"stream_event","event":{"type":"content_block_stop","index":0},"session_id":"3efe0143"}"#,
        #"{"type":"stream_event","event":{"type":"message_start","message":{"id":"msg_011","role":"assistant","content":[]}},"ttft_ms":732,"session_id":"3efe0143"}"#,
        #"{"type":"stream_event","event":{"type":"message_stop"},"session_id":"3efe0143"}"#,
        #"{"type":"system","subtype":"init","cwd":"/tmp","tools":[],"mcp_servers":[],"model":"claude-haiku-5-5","plugins":[]}"#,
        #"{"type":"system","subtype":"status","status":"requesting","session_id":"df84df3c"}"#,
        #"{"type":"system","subtype":"thinking_tokens","estimated_tokens":50,"estimated_tokens_delta":50,"session_id":"d40c8eff"}"#,
        #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Bonjour"}]},"session_id":"3efe0143"}"#,
        #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]},"session_id":"d40c8eff"}"#,
        #"{"type":"rate_limit_event","rate_limit_info":{"status":"allowed"},"session_id":"3efe0143"}"#,
        #"{"type":"control_response","response":{"subtype":"success","request_id":"req-1","response":{"still_queued":[]}}}"#,
    ])
    func otherLinesAreIgnored(line: String) throws {
        #expect(try parser.parse(line) == nil)
    }

    @Test(arguments: ["", "ligne invalide", "{", #"{"subtype":"init"}"#])
    func invalidLineThrows(line: String) {
        #expect(throws: (any Error).self) {
            try parser.parse(line)
        }
    }
}
