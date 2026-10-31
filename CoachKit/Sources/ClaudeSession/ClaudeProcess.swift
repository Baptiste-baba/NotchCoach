import Foundation

/// Un process `claude` lancé, avec ses pipes : écriture sur stdin, lecture de stdout ligne par ligne.
final class ClaudeProcess {
    /// Lance le process.
    init(configuration: ClaudeLaunchConfiguration) throws {
        fatalError("TODO")
    }

    /// Lignes de stdout. La séquence se termine quand le process meurt.
    var outputLines: AsyncLineSequence<FileHandle.AsyncBytes> {
        fatalError("TODO")
    }

    /// Écrit une ligne sur stdin.
    func write(line: String) throws {
        fatalError("TODO")
    }

    func terminate() {
        fatalError("TODO")
    }
}
