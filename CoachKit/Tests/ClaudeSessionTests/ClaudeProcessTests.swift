import Foundation
import Testing
@testable import ClaudeSession

struct ClaudeProcessTests {
    /// Régression : un lecteur bloqué sur stderr, ouvert mais muet, ne doit pas empêcher la lecture de stdout
    /// tant que le process reste vivant (le cas de `claude`, lancé pour tout le call).
    @Test func readsEveryStdoutLineWhileStderrStaysOpenAndSilent() async throws {
        let process = try ClaudeProcess(configuration: ClaudeLaunchConfiguration(
            executableURL: URL(filePath: "/bin/sh"),
            arguments: ["-c", "echo un; sleep 0.3; echo deux; sleep 10"],
            environment: [:],
            workingDirectory: URL(filePath: NSTemporaryDirectory())
        ))
        defer { process.terminate() }
        let received = LinesRecorder()
        let lines = process.outputLines
        let reader = Task {
            for await line in lines {
                await received.append(line)
            }
        }
        defer { reader.cancel() }

        try await Task.sleep(for: .seconds(1.5))

        #expect(await received.lines == ["un", "deux"])
    }
}

private actor LinesRecorder {
    private(set) var lines: [String] = []

    func append(_ line: String) {
        lines.append(line)
    }
}
