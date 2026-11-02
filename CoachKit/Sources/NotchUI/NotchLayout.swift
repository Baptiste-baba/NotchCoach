import CoreGraphics

/// Calcul pur du cadre du panel : sur la notch, ou en pilule centrée en haut de l'écran sans notch.
struct NotchLayout {
    /// Débord du panel de chaque côté de la notch, pour qu'il la prolonge visiblement.
    var notchSideExtension: CGFloat = 12
    /// Taille de la pilule quand l'écran n'a pas de notch.
    var pillSize = CGSize(width: 200, height: 32)
    /// Écart entre le haut de l'écran et la pilule.
    var pillTopMargin: CGFloat = 4
    /// Largeur du panel déplié : fixe, seule sa hauteur suit le texte.
    var expandedWidth: CGFloat = 440
    /// Hauteur minimale de la zone de texte : une ligne et ses marges.
    var minimumExpandedContentHeight: CGFloat = 40
    /// Part maximale de la hauteur de l'écran que le panel déplié occupe, depuis le haut. Au-delà, le texte défile.
    var maximumExpandedHeightFraction: CGFloat = 1.0 / 3

    func placement(for screen: ScreenMetrics) -> NotchPlacement {
        if let notch = notchFrame(on: screen) {
            return NotchPlacement(frame: notch.insetBy(dx: -notchSideExtension, dy: 0), style: .notch)
        }

        let frame = CGRect(
            x: screen.frame.midX - pillSize.width / 2,
            y: screen.frame.maxY - pillTopMargin - pillSize.height,
            width: pillSize.width,
            height: pillSize.height
        )
        return NotchPlacement(frame: frame, style: .pill)
    }

    /// Largeur du panel déplié sur cet écran, pour mesurer la hauteur du texte avant de le placer.
    func expandedWidth(for screen: ScreenMetrics) -> CGFloat {
        guard let notch = notchFrame(on: screen) else { return expandedWidth }
        return max(expandedWidth, notch.width + 2 * notchSideExtension)
    }

    /// Cadre du panel déplié : il descend sous la notch (ou sous la pilule) de la hauteur du texte, sans dépasser
    /// le plafond. Ancré en haut de l'écran : seul son bas bouge quand le texte grandit.
    func expandedPlacement(for screen: ScreenMetrics, contentHeight: CGFloat) -> NotchPlacement {
        let notch = notchFrame(on: screen)
        // Sur la notch : collé en haut, il la recouvre puis descend en dessous pour le texte.
        // En pilule : sous la marge du haut, le texte commence tout de suite.
        let topMargin = notch == nil ? pillTopMargin : 0
        let contentTopInset = notch?.height ?? 0
        let width = expandedWidth(for: screen)
        let maximumHeight = (screen.frame.height * maximumExpandedHeightFraction).rounded(.down) - topMargin
        let height = contentTopInset
            + clampedContentHeight(contentHeight, maximum: maximumHeight - contentTopInset)
        let frame = CGRect(
            x: (notch?.midX ?? screen.frame.midX) - width / 2,
            y: screen.frame.maxY - topMargin - height,
            width: width,
            height: height
        )
        return NotchPlacement(frame: frame, style: notch == nil ? .pill : .notch, contentTopInset: contentTopInset)
    }

    private func clampedContentHeight(_ height: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(height.rounded(.up), minimumExpandedContentHeight), max(maximum, minimumExpandedContentHeight))
    }

    /// Cadre de la notch matérielle, ou `nil` si l'écran n'en a pas ou si ses mesures sont incohérentes
    /// (une seule zone de barre de menus, hauteur nulle, zones qui se chevauchent) : on retombe alors sur la pilule.
    private func notchFrame(on screen: ScreenMetrics) -> CGRect? {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
              screen.safeAreaTopInset > 0,
              right.minX > left.maxX
        else { return nil }

        // La notch occupe l'espace entre les deux zones de barre de menus.
        return CGRect(
            x: left.maxX,
            y: screen.frame.maxY - screen.safeAreaTopInset,
            width: right.minX - left.maxX,
            height: screen.safeAreaTopInset
        )
    }
}
