import Foundation

/// Options de lancement passées en ligne de commande, comme `--replay <fichier.wav>`.
struct LaunchOptions: Equatable {
    /// Fichier à rejouer à la place d'un vrai call ; `nil` hors mode replay.
    var replayFile: URL?

    init(arguments: [String]) {}
}
