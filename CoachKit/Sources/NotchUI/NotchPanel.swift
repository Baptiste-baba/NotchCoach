import AppKit

/// Panel flottant affiché sur la notch : ne prend jamais le focus, reste invisible en partage d'écran.
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // Non négociable : invisible pendant un partage d'écran (test manuel de la checklist de release).
        sharingType = .none
        // Un panel se masque par défaut quand l'app perd le focus ; la nôtre ne l'a jamais.
        hidesOnDeactivate = false
        // Au-dessus de la barre de menus : les clics doivent atteindre les éléments qu'il recouvre.
        // À désactiver le jour où l'état déplié devient interactif.
        ignoresMouseEvents = true
        isMovable = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
    }

    override var canBecomeKey: Bool { false }

    override var canBecomeMain: Bool { false }
}
