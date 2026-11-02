import Foundation

/// Options de lancement passées en ligne de commande, comme `--replay <fichier.wav>`.
struct LaunchOptions: Equatable {
    /// Fichier à rejouer à la place d'un vrai call ; `nil` hors mode replay.
    var replayFile: URL?

    init(arguments: [String]) {
        if let flag = arguments.firstIndex(of: "--replay"), arguments.indices.contains(flag + 1) {
            // Un chemin relatif part du répertoire courant, celui du terminal qui lance l'app.
            replayFile = URL(fileURLWithPath: arguments[flag + 1])
        }
    }
}
