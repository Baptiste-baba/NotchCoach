import Foundation

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
        process.executableURL = configuration.executableURL
        process.arguments = configuration.arguments
        process.environment = configuration.environment
        process.currentDirectoryURL = configuration.workingDirectory
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        try process.run()

        self.process = process
        input = inputPipe.fileHandleForWriting
        let (lines, continuation) = AsyncStream<String>.makeStream()
        outputLines = lines
        let output = outputPipe.fileHandleForReading
        Task.detached {
            // Découpage sur `\n` uniquement (JSON Lines) : `AsyncLineSequence` couperait aussi sur U+2028,
            // que le CLI laisse tel quel dans les chaînes JSON.
            var buffer: [UInt8] = []
            do {
                for try await byte in output.bytes {
                    if byte == UInt8(ascii: "\n") {
                        continuation.yield(String(decoding: buffer, as: UTF8.self))
                        buffer.removeAll(keepingCapacity: true)
                    } else {
                        buffer.append(byte)
                    }
                }
            } catch {}
            continuation.finish()
        }
    }

    /// Écrit une ligne sur stdin.
    func write(line: String) throws {
        try input.write(contentsOf: Data((line + "\n").utf8))
    }

    func terminate() {
        process.terminate()
    }
}
