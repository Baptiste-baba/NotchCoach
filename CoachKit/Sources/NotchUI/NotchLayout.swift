import CoreGraphics

/// Calcul pur du cadre du panel : sur la notch, ou en pilule centrée en haut de l'écran sans notch.
struct NotchLayout {
    /// Débord du panel de chaque côté de la notch, pour qu'il la prolonge visiblement.
    var notchSideExtension: CGFloat = 12
    /// Taille de la pilule quand l'écran n'a pas de notch.
    var pillSize = CGSize(width: 200, height: 32)
    /// Écart entre le haut de l'écran et la pilule.
    var pillTopMargin: CGFloat = 4

    func placement(for screen: ScreenMetrics) -> NotchPlacement {
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            // La notch occupe l'espace entre les deux zones de barre de menus.
            let height = screen.safeAreaTopInset
            let frame = CGRect(
                x: left.maxX - notchSideExtension,
                y: screen.frame.maxY - height,
                width: right.minX - left.maxX + 2 * notchSideExtension,
                height: height
            )
            return NotchPlacement(frame: frame, style: .notch)
        }

        let frame = CGRect(
            x: screen.frame.midX - pillSize.width / 2,
            y: screen.frame.maxY - pillTopMargin - pillSize.height,
            width: pillSize.width,
            height: pillSize.height
        )
        return NotchPlacement(frame: frame, style: .pill)
    }
}
