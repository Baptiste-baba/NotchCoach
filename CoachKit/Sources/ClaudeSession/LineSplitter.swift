import Foundation
import Synchronization

/// Découpe un flux d'octets en lignes sur `\n` uniquement (JSON Lines) : `AsyncLineSequence` couperait aussi
/// sur U+2028, que le CLI peut laisser tel quel dans les chaînes JSON.
final class LineSplitter: Sendable {
    private let pending = Mutex<[UInt8]>([])

    /// Ajoute des octets et renvoie les lignes complètes ; une ligne incomplète attend la suite.
    func append(_ data: Data) -> [String] {
        pending.withLock { buffer in
            buffer.append(contentsOf: data)
            var lines: [String] = []
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                lines.append(String(decoding: buffer[..<newline], as: UTF8.self))
                buffer.removeSubrange(...newline)
            }
            return lines
        }
    }
}
