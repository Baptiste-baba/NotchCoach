import Testing
@testable import ClaudeSession

/// Sortie du CLI avec `--output-format json`, réduite aux champs utiles, comme relevée sur Claude Code 2.1.310.
private func result(isError: Bool, text: String) -> String {
    #"{"type":"result","subtype":"success","is_error":\#(isError),"duration_ms":2726,"num_turns":1,"result":"\#(text)"}"# + "\n"
}

struct ClaudeCompletionTests {
    @Test func responseIsTheResultText() throws {
        #expect(try ClaudeCompletion.response(fromOutput: result(isError: false, text: "bonjour")) == "bonjour")
    }

    @Test func errorResultFailsWithItsMessageDespiteSuccessSubtype() {
        #expect(throws: ClaudeSessionError.responseFailed(message: "Claude AI usage limit reached")) {
            try ClaudeCompletion.response(fromOutput: result(isError: true, text: "Claude AI usage limit reached"))
        }
    }

    @Test(arguments: [
        "",
        "Error: Not logged in\n",
        #"{"type":"system","subtype":"init"}"#,
        #"{"type":"result","subtype":"success","is_error":false}"#,
    ])
    func outputWithoutAResultIsInvalid(output: String) {
        #expect(throws: ClaudeSessionError.invalidResponse) { try ClaudeCompletion.response(fromOutput: output) }
    }
}
