#if DEBUG
import ClaudeSession
import NotchUI

/// Outil de debug de l'étape 2 : envoie un prompt fixe à la session Claude et affiche la réponse dans la notch.
final class ClaudeDebugProbe {
    private let notch: NotchPanelController

    init(notch: NotchPanelController) {
        self.notch = notch
    }

    /// Lance la session au premier appel, puis envoie le prompt fixe.
    func run() {
        fatalError("TODO")
    }
}
#endif
