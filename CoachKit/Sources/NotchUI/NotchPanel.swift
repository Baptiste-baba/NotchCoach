import AppKit

/// Panel flottant affiché sur la notch : ne prend jamais le focus, reste invisible en partage d'écran.
final class NotchPanel: NSPanel {
    init() {
        fatalError("TODO")
    }

    override var canBecomeKey: Bool {
        fatalError("TODO")
    }

    override var canBecomeMain: Bool {
        fatalError("TODO")
    }
}
