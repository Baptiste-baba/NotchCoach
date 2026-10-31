import Foundation

/// Encode les lignes `stream-json` à écrire sur stdin (sans le saut de ligne final).
struct StreamJSONEncoder {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    func line(for prompt: String) throws -> String {
        try encode(StreamInputMessage(message: .init(content: prompt)))
    }

    func interruptLine(requestID: String) throws -> String {
        try encode(StreamInterruptRequest(requestID: requestID))
    }

    private func encode(_ value: some Encodable) throws -> String {
        String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
