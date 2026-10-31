import AppKit
import SwiftUI

/// Possède le panel de la notch et gère son affichage.
/// Le panel est toujours sur l'écran principal et le suit quand la configuration des écrans change.
@MainActor
public final class NotchPanelController {
    private let layout = NotchLayout()
    private let panel: NotchPanel
    private let hostingView: NSHostingView<NotchView>
    private var screenObserver: (any NSObjectProtocol)?

    public init() {
        panel = NotchPanel()
        hostingView = NSHostingView(rootView: NotchView(style: .notch))
        // C'est le cadre calculé par NotchLayout qui fixe la taille du panel, pas le contenu SwiftUI.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
    }

    /// Affiche le panel, positionné sur la notch ou en pilule sans notch.
    public func show() {
        reposition()
        panel.orderFrontRegardless()
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    /// Masque le panel.
    public func hide() {
        panel.orderOut(nil)
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
    }

    private func reposition() {
        // L'écran principal choisi dans Réglages > Moniteurs est toujours le premier ; `NSScreen.main` suit le focus.
        guard let screen = NSScreen.screens.first else { return }
        let placement = layout.placement(for: ScreenMetrics(screen: screen))
        hostingView.rootView = NotchView(style: placement.style)
        panel.setFrame(placement.frame, display: true)
    }
}
