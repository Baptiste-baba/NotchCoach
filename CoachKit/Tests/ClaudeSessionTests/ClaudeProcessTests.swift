import Foundation
import Testing
@testable import ClaudeSession

struct ClaudeProcessTests {
    func launch(_ command: String) throws -> ClaudeProcess {
        try ClaudeProcess(configuration: ClaudeLaunchConfiguration(
            executableURL: URL(filePath: "/bin/sh"),
            arguments: ["-c", command],
            environment: [:],
            workingDirectory: URL(filePath: NSTemporaryDirectory())
        ))
    }

    /// Régression : un lecteur bloqué sur stderr, ouvert mais muet, ne doit pas empêcher la lecture de stdout
    /// tant que le process reste vivant (le cas de `claude`, lancé pour tout le call).
    @Test func readsEveryStdoutLineWhileStderrStaysOpenAndSilent() async throws {
        let process = try launch("echo un; sleep 0.3; echo deux; sleep 10")
        defer { process.terminate() }
        let (lines, reader) = record(process.outputLines)
        defer { reader.cancel() }

        #expect(await eventually(timeout: .seconds(1.5)) { await lines.values == ["un", "deux"] })
    }

    @Test func writtenLinesReachStdin() async throws {
        let process = try launch("cat")
        defer { process.terminate() }
        let (lines, reader) = record(process.outputLines)
        defer { reader.cancel() }

        try process.write(line: #"{"type":"user"}"#)

        #expect(await eventually { await lines.values == [#"{"type":"user"}"#] })
    }

    @Test func outputEndsWhenTheProcessDies() async throws {
        let process = try launch("echo dernier")
        var lines: [String] = []

        for await line in process.outputLines {
            lines.append(line)
        }

        #expect(lines == ["dernier"])
    }

    /// Sans protection, écrire vers un process mort enverrait SIGPIPE, qui tuerait le process de test.
    @Test func writingToADeadProcessThrowsInsteadOfCrashing() async throws {
        let process = try launch("exit 0")
        for await _ in process.outputLines {}

        #expect(throws: (any Error).self) {
            for _ in 0..<100 {
                try process.write(line: "ligne")
            }
        }
    }

    @Test func missingExecutableFailsToLaunch() {
        #expect {
            try ClaudeProcess(configuration: ClaudeLaunchConfiguration(
                executableURL: URL(filePath: "/nexiste/pas"),
                arguments: [],
                environment: [:],
                workingDirectory: URL(filePath: NSTemporaryDirectory())
            ))
        } throws: { error in
            if case ClaudeSessionError.launchFailed = error { true } else { false }
        }
    }

    @Test func terminateEndsOutput() async throws {
        let process = try launch("sleep 10")

        process.terminate()

        for await _ in process.outputLines {}
    }
}
