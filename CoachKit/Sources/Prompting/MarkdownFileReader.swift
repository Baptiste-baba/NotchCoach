import Foundation

/// Lecture d'un fichier Markdown écrit par l'utilisateur, avec les échecs communs au prompt et au playbook d'un profil.
enum MarkdownFileReader {
    enum Failure: Error, Equatable {
        case unreadable(reason: String)
        case notUTF8
        case tooLong(characterCount: Int)
    }

    /// Texte du fichier, en UTF-8, de `maximumLength` caractères au plus.
    static func read(_ url: URL, maximumLength: Int) throws(Failure) -> String {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw .unreadable(reason: error.localizedDescription)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw .notUTF8
        }
        guard text.count <= maximumLength else {
            throw .tooLong(characterCount: text.count)
        }
        return text
    }
}
