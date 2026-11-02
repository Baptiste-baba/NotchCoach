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
    /// Mesure la hauteur du texte avec la même vue que celle affichée, pour que le panel la contienne exactement.
    private let textMeasurer = NSHostingController(rootView: NotchExpandedText(text: ""))

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
        let placement: NotchPlacement
        switch content {
        case .empty:
            placement = layout.placement(for: metrics)
        case .text(let text):
            let width = layout.expandedWidth(for: metrics)
            placement = layout.expandedPlacement(for: metrics, contentHeight: height(of: text, width: width))
        }
        logger.debug("Panel \(String(describing: placement.style), privacy: .public) en \(placement.frame.debugDescription, privacy: .public)")
        // Replié, il laisse passer les clics vers la barre de menus ; déplié, il reçoit le défilement du trackpad.
        // Il ne devient jamais la fenêtre active pour autant.
        panel.ignoresMouseEvents = content == .empty
        hostingView.rootView = NotchView(
            style: placement.style,
            contentTopInset: placement.contentTopInset,
            content: content
        )
        if panel.isVisible, panel.frame != placement.frame {
            // Animation sobre : le panel s'allonge ou se replie depuis le haut, sans saut.
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().setFrame(placement.frame, display: true)
            }
        } else {
            panel.setFrame(placement.frame, display: true)
        }
        panel.orderFrontRegardless()
    }

    private func height(of text: String, width: CGFloat) -> CGFloat {
        textMeasurer.rootView = NotchExpandedText(text: text)
        return textMeasurer.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }
}
