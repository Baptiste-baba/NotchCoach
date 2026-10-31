import AppKit
import os
import SwiftUI

private let logger = Logger(subsystem: "io.github.baptiste-baba.NotchCoach", category: "NotchUI")

/// Possède le panel de la notch et gère son affichage.
/// Le panel est toujours sur l'écran principal et le suit quand la configuration des écrans change.
@MainActor
public final class NotchPanelController {
    private let layout = NotchLayout()
    private let panel: NotchPanel
    private let hostingView: NSHostingView<NotchView>
    private var screenObserver: (any NSObjectProtocol)?
    /// Une notification d'écran déjà en file peut arriver après `hide()` : elle ne doit pas réafficher le panel.
    private var isShown = false
    private var content: NotchContent = .empty

    public init() {
        panel = NotchPanel()
        hostingView = NSHostingView(rootView: NotchView(style: .notch))
        // C'est le cadre calculé par NotchLayout qui fixe la taille du panel, pas le contenu SwiftUI.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
    }

    /// Affiche le panel, positionné sur la notch ou en pilule sans notch.
    public func show() {
        isShown = true
        reposition()
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    /// Change le contenu affiché : `.empty` replie le panel, `.text` le déplie sous la notch.
    public func display(_ content: NotchContent) {
        self.content = content
        reposition()
    }

    /// Masque le panel.
    public func hide() {
        isShown = false
        panel.orderOut(nil)
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
    }

    private func reposition() {
        guard isShown else { return }
        // L'écran principal choisi dans Réglages > Moniteurs est toujours le premier ; `NSScreen.main` suit le focus.
        guard let screen = NSScreen.screens.first else {
            // MacBook fermé sans écran externe : le retour d'un écran déclenchera un nouveau repositionnement.
            logger.notice("Aucun écran disponible, panel masqué")
            panel.orderOut(nil)
            return
        }
        let metrics = ScreenMetrics(screen: screen)
        let placement = content == .empty ? layout.placement(for: metrics) : layout.expandedPlacement(for: metrics)
        logger.debug("Panel \(String(describing: placement.style), privacy: .public) en \(placement.frame.debugDescription, privacy: .public)")
        hostingView.rootView = NotchView(
            style: placement.style,
            contentTopInset: placement.contentTopInset,
            content: content
        )
        panel.setFrame(placement.frame, display: true)
        panel.orderFrontRegardless()
    }
}
