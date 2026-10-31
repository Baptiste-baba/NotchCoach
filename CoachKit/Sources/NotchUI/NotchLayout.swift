import CoreGraphics

/// Calcul pur du cadre du panel : sur la notch, ou en pilule centrée en haut de l'écran sans notch.
struct NotchLayout {
    /// Débord du panel de chaque côté de la notch, pour qu'il la prolonge visiblement.
    var notchSideExtension: CGFloat = 12
    /// Taille de la pilule quand l'écran n'a pas de notch.
    var pillSize = CGSize(width: 200, height: 32)
    /// Écart entre le haut de l'écran et la pilule.
    var pillTopMargin: CGFloat = 4
    /// Taille de la zone de texte du panel déplié, sous la notch.
    var expandedContentSize = CGSize(width: 440, height: 80)

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

    /// Cadre du panel déplié : il descend sous la notch (ou sous la pilule) pour afficher du texte.
    func expandedPlacement(for screen: ScreenMetrics) -> NotchPlacement {
        let content = expandedContentSize
        if let notch = notchFrame(on: screen) {
            // Centré sur la notch, il la recouvre puis descend en dessous pour le texte.
            let width = max(content.width, notch.width + 2 * notchSideExtension)
            let height = notch.height + content.height
            let frame = CGRect(
                x: notch.midX - width / 2,
                y: screen.frame.maxY - height,
                width: width,
                height: height
            )
            return NotchPlacement(frame: frame, style: .notch, contentTopInset: notch.height)
        }

        let frame = CGRect(
            x: screen.frame.midX - content.width / 2,
            y: screen.frame.maxY - pillTopMargin - content.height,
            width: content.width,
            height: content.height
        )
        return NotchPlacement(frame: frame, style: .pill)
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
