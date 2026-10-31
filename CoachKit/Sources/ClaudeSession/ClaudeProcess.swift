import Foundation
import os

private let logger = Logger(subsystem: "io.github.baptiste-baba.NotchCoach", category: "ClaudeSession")

/// Un process `claude` lancé, avec ses pipes : écriture sur stdin, lecture de stdout ligne par ligne.
final class ClaudeProcess {
    /// Lignes de stdout. Le flux se termine quand le process meurt (stdout fermé).
    let outputLines: AsyncStream<String>

    private let process: Process
    private let input: FileHandle

    /// Lance le process.
    init(configuration: ClaudeLaunchConfiguration) throws {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = configuration.executableURL
        process.arguments = configuration.arguments
        process.environment = configuration.environment
        process.currentDirectoryURL = configuration.workingDirectory
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        // Écrire dans le pipe d'un process mort enverrait SIGPIPE, qui tuerait l'app : on veut une erreur à la place.
        _ = fcntl(inputPipe.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        do {
            try process.run()
        } catch {
            throw ClaudeSessionError.launchFailed(reason: error.localizedDescription)
        }

        self.process = process
        input = inputPipe.fileHandleForWriting
        outputLines = Self.lines(of: outputPipe.fileHandleForReading)
        let errorLines = Self.lines(of: errorPipe.fileHandleForReading)
        Task.detached {
            for await line in errorLines {
                logger.error("stderr claude : \(line, privacy: .private)")
            }
        }
    }

    /// Écrit une ligne sur stdin. Lève une erreur si le process est mort.
    func write(line: String) throws {
        try input.write(contentsOf: Data((line + "\n").utf8))
    }

    func terminate() {
        if process.isRunning {
            process.terminate()
        }
    }

    /// Lit un pipe ligne par ligne, avec un `readabilityHandler` propre à chaque pipe. Avec `FileHandle.bytes`,
    /// un lecteur en attente sur un pipe muet (stderr) bloquait la lecture de stdout.
    private static func lines(of handle: FileHandle) -> AsyncStream<String> {
        let (lines, continuation) = AsyncStream<String>.makeStream()
        let splitter = LineSplitter()
        handle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                // Fin du flux : le process est mort.
                handle.readabilityHandler = nil
                continuation.finish()
                return
            }
            for line in splitter.append(data) {
                continuation.yield(line)
            }
        }
        return lines
    }
}
